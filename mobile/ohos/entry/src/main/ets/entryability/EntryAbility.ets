import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { RdbBridge } from '../rdb/RdbBridge';
import { NotifyBridge } from '../notify/NotifyBridge';

/// 与 Dart 侧 lib/data/storage_paths.dart 约定的通道。
const PATH_CHANNEL: string = 'caldav_free/paths';
const PATH_SUPPORT_DIRECTORY: string = 'supportDirectory';

/// 历记（caldav-free）鸿蒙入口 Ability。
///
/// 除了拉起 Flutter 引擎，还承担 Android MainActivity.kt 里那份有限的
/// 原生职责：
/// 1. 把应用私有沙箱目录 filesDir 交给 Dart 侧，用于存放登录凭据；
/// 2. 注册 RelationalStore 桥接，让 drift 在鸿蒙上落到系统数据库。
export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    const messenger: BinaryMessenger =
      flutterEngine.getDartExecutor().getBinaryMessenger();
    this.registerPathsChannel(messenger);
    new RdbBridge(this.context).attach(messenger);
    // 原生通知：即时通知走 notificationManager，定时提醒走 reminderAgentManager
    new NotifyBridge(this.context).attach(messenger);
  }

  private registerPathsChannel(messenger: BinaryMessenger): void {
    const filesDir: string = this.context.filesDir;

    const pathsChannel: MethodChannel = new MethodChannel(messenger, PATH_CHANNEL);
    const handler: MethodCallHandler = {
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (call.method === PATH_SUPPORT_DIRECTORY) {
          result.success(filesDir);
        } else {
          result.notImplemented();
        }
      },
    };
    pathsChannel.setMethodCallHandler(handler);
  }
}
