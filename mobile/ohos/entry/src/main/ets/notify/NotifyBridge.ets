import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';

const CHANNEL_NAME: string = 'caldav_free/notify';
const ABILITY_NAME: string = 'EntryAbility';

/// 错误对象直接拼字符串会得到 "[object Object]"，把 code/message 抠出来才定位得到。
function errText(error: ESObject): string {
  const be = error as BusinessError;
  const code: number | undefined = be.code;
  const message: string | undefined = be.message;
  if (code !== undefined || message !== undefined) {
    return `code=${code} message=${message}`;
  }
  return `${error}`;
}

/// 鸿蒙原生通知桥，对端是 `lib/data/reminders/ohos_notification_gateway.dart`。
///
/// 两套机制分工：
///   - 即时通知（设置页的"发送测试通知"、漏提醒汇总）走 `notificationManager.publish`
///   - 定时提醒（任务到期）走 `reminderAgentManager`：由系统代理守着，应用退到后台
///     甚至被杀也能准点响，这是纯 `notificationManager` 做不到的
///
/// 注意点：
///   - `requestEnableNotification(context)` 会弹系统授权框，用户拒绝时抛 1600004，
///     这里吞掉异常并返回当前真实状态，避免 Dart 侧把"拒绝"当成崩溃
///   - ReminderRequest 的 `notificationId` 用 Dart 侧的提醒 id，方便排查和去重
///   - 排程 id 是系统返回的，重启后内存映射会丢；`cancelPending` 直接
///     `cancelAllReminders()`，因为调度器启动时本来就会全量重排
///
/// 通道协议：
///   requestPermission              -> bool
///   permissionStatus               -> bool
///   showNow  {id,title,body,payload}       -> null
///   schedule {id,at,title,body,payload,repeatDaily} -> null
///   cancelPending / cancelAll      -> null
export class NotifyBridge {
  private context: common.UIAbilityContext;
  /// Dart 侧提醒 id → 系统 reminderId。仅用于同一次运行内精确取消。
  private reminderIds: Map<number, number> = new Map<number, number>();

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  attach(messenger: BinaryMessenger): void {
    const channel: MethodChannel = new MethodChannel(messenger, CHANNEL_NAME);
    const handler: MethodCallHandler = {
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.dispatch(call, result);
      },
    };
    channel.setMethodCallHandler(handler);
  }

  private dispatch(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'requestPermission':
        this.requestPermission(result);
        break;
      case 'permissionStatus':
        this.permissionStatus(result);
        break;
      case 'showNow':
        this.showNow(call, result);
        break;
      case 'schedule':
        this.schedule(call, result);
        break;
      case 'cancelPending':
      case 'cancelAll':
        this.cancelAllReminders(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  // ---- 参数读取：MethodCall.argument 返回 ESObject，ArkTS 禁止隐式使用 ----
  private stringArg(call: MethodCall, key: string, fallback: string): string {
    const value: ESObject = call.argument(key);
    return typeof value === 'string' ? value as string : fallback;
  }

  private numberArg(call: MethodCall, key: string, fallback: number): number {
    const value: ESObject = call.argument(key);
    return typeof value === 'number' ? value as number : fallback;
  }

  private boolArg(call: MethodCall, key: string, fallback: boolean): boolean {
    const value: ESObject = call.argument(key);
    return typeof value === 'boolean' ? value as boolean : fallback;
  }

  private async requestPermission(result: MethodResult): Promise<void> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(this.context);
      }
      result.success(await notificationManager.isNotificationEnabled());
    } catch (error) {
      // 1600004 = 用户拒绝，不是异常路径，按"未开启"回给 Dart
      console.info(`[NotifyBridge] requestPermission not granted: ${errText(error)}`);
      result.success(false);
    }
  }

  private async permissionStatus(result: MethodResult): Promise<void> {
    try {
      result.success(await notificationManager.isNotificationEnabled());
    } catch (error) {
      console.error(`[NotifyBridge] permissionStatus failed: ${errText(error)}`);
      result.success(false);
    }
  }

  /// 点通知回到本应用，并把 payload 塞进 want 参数。
  private async buildNotificationWantAgent(payload: string): Promise<WantAgent> {
    const parameters: Record<string, Object> = { 'payload': payload };
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: this.context.abilityInfo.bundleName,
          abilityName: ABILITY_NAME,
          parameters: parameters,
        },
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };
    return await wantAgent.getWantAgent(info);
  }

  private reminderWantAgent(payload: string): reminderAgentManager.WantAgent {
    const parameters: Record<string, Object> = { 'payload': payload };
    const agent: reminderAgentManager.WantAgent = {
      pkgName: this.context.abilityInfo.bundleName,
      abilityName: ABILITY_NAME,
      parameters: parameters,
    };
    return agent;
  }

  private async showNow(call: MethodCall, result: MethodResult): Promise<void> {
    const id: number = this.numberArg(call, 'id', 1);
    const title: string = this.stringArg(call, 'title', '提醒');
    const body: string = this.stringArg(call, 'body', '');
    const payload: string = this.stringArg(call, 'payload', '');
    try {
      const request: notificationManager.NotificationRequest = {
        id: id,
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: body,
          },
        },
        wantAgent: await this.buildNotificationWantAgent(payload),
        tapDismissed: true,
      };
      await notificationManager.publish(request);
      console.info(`[NotifyBridge] published id=${id} title=${title}`);
      result.success(null);
    } catch (error) {
      console.error(`[NotifyBridge] publish FAILED id=${id} err=${errText(error)}`);
      result.error('notify_publish', `${errText(error)}`, null);
    }
  }

  private async schedule(call: MethodCall, result: MethodResult): Promise<void> {
    const id: number = this.numberArg(call, 'id', 0);
    const atMillis: number = this.numberArg(call, 'at', 0);
    const title: string = this.stringArg(call, 'title', '任务提醒');
    const body: string = this.stringArg(call, 'body', '');
    const payload: string = this.stringArg(call, 'payload', '');
    const repeatDaily: boolean = this.boolArg(call, 'repeatDaily', false);
    try {
      const at: Date = new Date(atMillis);
      const hour: number = at.getHours();
      const minute: number = at.getMinutes();
      const agent: reminderAgentManager.WantAgent = this.reminderWantAgent(payload);
      let reminderId: number;
      if (repeatDaily) {
        // 每天固定时刻：Alarm 比 Calendar 更贴合，系统按天循环，不用逐个日期铺
        const request: reminderAgentManager.ReminderRequestAlarm = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
          hour: hour,
          minute: minute,
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          title: title,
          content: body,
          notificationId: id,
          wantAgent: agent,
          ringDuration: 5,
          snoozeTimes: 2,
          timeInterval: 600,
        };
        reminderId = await reminderAgentManager.publishReminder(request);
      } else {
        const request: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: at.getFullYear(),
            month: at.getMonth() + 1,
            day: at.getDate(),
            hour: hour,
            minute: minute,
            second: at.getSeconds(),
          },
          title: title,
          content: body,
          notificationId: id,
          wantAgent: agent,
          ringDuration: 5,
          snoozeTimes: 2,
          timeInterval: 600,
        };
        reminderId = await reminderAgentManager.publishReminder(request);
      }
      this.reminderIds.set(id, reminderId);
      console.info(`[NotifyBridge] scheduled id=${id} reminderId=${reminderId} at=${atMillis} daily=${repeatDaily}`);
      result.success(null);
    } catch (error) {
      console.error(`[NotifyBridge] schedule FAILED id=${id} at=${atMillis} err=${errText(error)}`);
      result.error('notify_schedule', `${errText(error)}`, null);
    }
  }

  private async cancelAllReminders(result: MethodResult): Promise<void> {
    try {
      const before: Array<reminderAgentManager.ReminderRequest> =
        await reminderAgentManager.getValidReminders();
      await reminderAgentManager.cancelAllReminders();
      const after: Array<reminderAgentManager.ReminderRequest> =
        await reminderAgentManager.getValidReminders();
      this.reminderIds.clear();
      // 这两个数字能直接看出"重排前有没有清干净"和"系统里堆了多少"
      console.info(`[NotifyBridge] cancelAll reminders before=${before.length} after=${after.length}`);
      result.success(null);
    } catch (error) {
      console.error(`[NotifyBridge] cancelAllReminders failed: ${errText(error)}`);
      result.error('notify_cancel', `${errText(error)}`, null);
    }
  }
}
