package store

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html"
	"strings"
	"testing"
	"time"
)

func TestParseDidaXLSX(t *testing.T) {
	data := buildDidaTestWorkbook(t, []didaTestSheet{{
		Name: "夜读",
		Basic: `基本信息
习惯名称：夜读
习惯状态：正常
目标：2 次/天
所属分组：工作
提醒时间：21:30
频率：每周 3 天`,
		Rows: [][]string{
			{"2026年10月20日", "21:30", "完成", "2", "😊", "读完一章"},
			{"2026年10月21日", "", "未完成", "0", "", ""},
		},
	}})
	sheets, err := parseDidaXLSX(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(sheets) != 1 {
		t.Fatalf("sheets = %d, want 1", len(sheets))
	}
	sheet := sheets[0]
	if sheet.SectionName != "工作" {
		t.Fatalf("section = %q, want 工作", sheet.SectionName)
	}
	habit := sheet.Habit.Habit
	if habit.Name != "夜读" || habit.Goal != 2 || habit.Unit != "Count" || !habit.RecordEnable {
		t.Fatalf("unexpected habit: %+v", habit)
	}
	if habit.Frequency != `{"type":"weekly","daysPerWeek":3}` {
		t.Fatalf("frequency = %s", habit.Frequency)
	}
	if habit.Reminders != `["21:30"]` {
		t.Fatalf("reminders = %s", habit.Reminders)
	}
	if len(sheet.Habit.Checkins) != 2 || len(sheet.Habit.Records) != 1 {
		t.Fatalf("checkins=%d records=%d", len(sheet.Habit.Checkins), len(sheet.Habit.Records))
	}
	if sheet.Habit.Checkins[0].Status != 2 || sheet.Habit.Checkins[1].Status != 1 {
		t.Fatalf("unexpected statuses: %+v", sheet.Habit.Checkins)
	}
	if sheet.Habit.Records[0].Content != "读完一章" || sheet.Habit.Records[0].Emoji != "😊" {
		t.Fatalf("unexpected record: %+v", sheet.Habit.Records[0])
	}
}

func TestParseDidaFrequencyAndUnit(t *testing.T) {
	data := buildDidaTestWorkbook(t, []didaTestSheet{{
		Name: "跑步",
		Basic: `基本信息
习惯名称：跑步
习惯状态：已归档
目标：30 分钟/天
频率：每 2 天`,
		Rows: [][]string{{"2026-10-20", "", "完成", "30", "", ""}},
	}})
	sheets, err := parseDidaXLSX(data)
	if err != nil {
		t.Fatal(err)
	}
	habit := sheets[0].Habit.Habit
	if habit.Status != 1 || habit.Goal != 30 || habit.Unit != "分钟" {
		t.Fatalf("unexpected habit: %+v", habit)
	}
	if habit.Frequency != `{"type":"interval","interval":2}` {
		t.Fatalf("frequency = %s", habit.Frequency)
	}
}

func TestParseDidaFrequencyVariants(t *testing.T) {
	cases := []struct {
		raw      string
		kind     string
		days     []int
		interval int
	}{
		{"每天", "daily", []int{0, 1, 2, 3, 4, 5, 6}, 0},
		{"工作日", "daily", []int{1, 2, 3, 4, 5}, 0},
		{"每周一、三、五", "daily", []int{1, 3, 5}, 0},
		{"每周 3 天", "weekly", nil, 0},
		{"每 2 天", "interval", nil, 2},
	}
	for _, tc := range cases {
		var freq HabitFrequency
		if err := json.Unmarshal([]byte(parseDidaFrequency(tc.raw)), &freq); err != nil {
			t.Fatalf("%s: %v", tc.raw, err)
		}
		if freq.Type != tc.kind || freq.Interval != tc.interval {
			t.Fatalf("%s = %+v, want type=%s interval=%d", tc.raw, freq, tc.kind, tc.interval)
		}
		if tc.days != nil && fmt.Sprint(freq.Weekdays) != fmt.Sprint(tc.days) {
			t.Fatalf("%s weekdays = %v, want %v", tc.raw, freq.Weekdays, tc.days)
		}
	}
}

func TestImportDidaHabits(t *testing.T) {
	s, userID := newTaskUser(t)
	data := buildDidaTestWorkbook(t, []didaTestSheet{{
		Name: "夜读",
		Basic: `基本信息
习惯名称：夜读
目标：1 次/天
所属分组：工作
频率：每天`,
		Rows: [][]string{
			{"2026年10月20日", "21:30", "完成", "1", "", "读完一章"},
		},
	}})
	result, err := s.ImportDidaHabits(context.Background(), userID, data, "append")
	if err != nil {
		t.Fatal(err)
	}
	if result.Habits != 1 || result.Checkins != 1 || result.Records != 1 {
		t.Fatalf("unexpected import result: %+v", result)
	}
	habits, err := s.ListHabits(context.Background(), userID, true)
	if err != nil || len(habits) != 1 {
		t.Fatalf("habits = %+v (%v)", habits, err)
	}
	if habits[0].SectionID == 0 {
		t.Fatal("section was not mapped")
	}
}

type didaTestSheet struct {
	Name  string
	Basic string
	Rows  [][]string
}

func buildDidaTestWorkbook(t *testing.T, sheets []didaTestSheet) []byte {
	t.Helper()
	var buf bytes.Buffer
	writer := zip.NewWriter(&buf)
	write := func(name, content string) {
		entry, err := writer.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := entry.Write([]byte(content)); err != nil {
			t.Fatal(err)
		}
	}
	var workbookSheets, rels strings.Builder
	for index, sheet := range sheets {
		fmt.Fprintf(&workbookSheets, `<sheet name="%s" r:id="rId%d" sheetId="%d"/>`, html.EscapeString(sheet.Name), index+1, index+1)
		fmt.Fprintf(&rels, `<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%d.xml"/>`, index+1, index+1)
		var rows strings.Builder
		allRows := append([][]string{{sheet.Basic}, {"日期", "时间", "完成情况", "完成量", "心情", "日志"}}, sheet.Rows...)
		for rowIndex, row := range allRows {
			fmt.Fprintf(&rows, `<row r="%d">`, rowIndex+1)
			for cellIndex, value := range row {
				if value == "" {
					continue
				}
				ref := fmt.Sprintf("%c%d", 'A'+cellIndex, rowIndex+1)
				fmt.Fprintf(&rows, `<c r="%s" t="inlineStr"><is><t>%s</t></is></c>`, ref, html.EscapeString(value))
			}
			rows.WriteString(`</row>`)
		}
		worksheet := `<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>` + rows.String() + `</sheetData></worksheet>`
		write(fmt.Sprintf("xl/worksheets/sheet%d.xml", index+1), worksheet)
	}
	write("xl/workbook.xml", `<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>`+workbookSheets.String()+`</sheets></workbook>`)
	write("xl/_rels/workbook.xml.rels", `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`+rels.String()+`</Relationships>`)
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestExportDidaHabitsRoundTrip(t *testing.T) {
	s, userID := newTaskUser(t)
	ctx := context.Background()
	now := time.Now()
	habit, err := s.CreateHabit(ctx, &Habit{
		UserID: userID, Name: "导出夜读", Goal: 2, Unit: "Count",
		Frequency: `{"type":"weekly","daysPerWeek":3}`,
		StartDate: stampOf(now.AddDate(0, 0, -2)),
		Reminders: `["21:30"]`,
	})
	if err != nil {
		t.Fatal(err)
	}
	section, err := s.CreateHabitSection(ctx, userID, "工作")
	if err != nil {
		t.Fatal(err)
	}
	updated := *habit
	updated.SectionID = section.ID
	if _, err := s.UpdateHabit(ctx, userID, habit.ID, &updated); err != nil {
		t.Fatal(err)
	}
	value := 2.0
	checkin, _, err := s.ToggleHabitCheckin(ctx, userID, habit.ID, stampOf(now), &value)
	if err != nil {
		t.Fatal(err)
	}
	if checkin == nil {
		t.Fatal("missing checkin")
	}
	if _, err := s.CreateHabitRecord(ctx, &HabitRecord{
		UserID: userID, HabitID: habit.ID, Stamp: stampOf(now), Content: "读完一章", Emoji: "😊",
	}); err != nil {
		t.Fatal(err)
	}
	data, err := s.ExportDidaHabits(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	sheets, err := parseDidaXLSX(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(sheets) != 1 {
		t.Fatalf("sheets = %d", len(sheets))
	}
	exported := sheets[0].Habit
	if exported.Habit.Name != "导出夜读" || exported.Habit.Goal != 2 || exported.Habit.Frequency != `{"type":"weekly","daysPerWeek":3}` {
		t.Fatalf("unexpected habit: %+v", exported.Habit)
	}
	if sheets[0].SectionName != "工作" || len(exported.Checkins) != 1 || len(exported.Records) != 1 {
		t.Fatalf("unexpected sheet: %+v", sheets[0])
	}
	if exported.Records[0].Content != "读完一章" || exported.Records[0].Emoji != "😊" {
		t.Fatalf("unexpected record: %+v", exported.Records[0])
	}
}
