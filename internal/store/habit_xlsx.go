package store

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"path"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const maxDidaImportBytes = 10 << 20
const maxDidaCheckins = 20000

type xlsxWorkbookXML struct {
	Sheets []xlsxSheetXML `xml:"sheets>sheet"`
}

type xlsxSheetXML struct {
	Name string `xml:"name,attr"`
	RID  string `xml:"http://schemas.openxmlformats.org/officeDocument/2006/relationships id,attr"`
}

type xlsxRelationshipsXML struct {
	Items []xlsxRelationshipXML `xml:"Relationship"`
}

type xlsxRelationshipXML struct {
	ID     string `xml:"Id,attr"`
	Target string `xml:"Target,attr"`
}

type xlsxSharedStringsXML struct {
	Items []xlsxSharedStringXML `xml:"si"`
}

type xlsxSharedStringXML struct {
	Texts []string `xml:"t"`
}

type xlsxWorksheetXML struct {
	Rows []xlsxRowXML `xml:"sheetData>row"`
}

type xlsxRowXML struct {
	Cells []xlsxCellXML `xml:"c"`
}

type xlsxCellXML struct {
	Ref    string `xml:"r,attr"`
	Type   string `xml:"t,attr"`
	Value  string `xml:"v"`
	Inline struct {
		Texts []string `xml:"t"`
	} `xml:"is"`
}

type didaSheet struct {
	Habit       *HabitBackupHabit
	SectionName string
}

var (
	didaGoalPattern     = regexp.MustCompile(`([0-9]+(?:\.[0-9]+)?)`)
	didaWeeklyPattern   = regexp.MustCompile(`每周\s*([0-9]+)\s*天`)
	didaIntervalPattern = regexp.MustCompile(`每\s*([0-9]+)\s*天`)
	didaReminderPattern = regexp.MustCompile(`([01]?[0-9]|2[0-3]):([0-5][0-9])`)
	didaChineseWeekdays = map[rune]int{'日': 0, '天': 0, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6}
	didaDateLayouts     = []string{"2006年01月02日", "2006-01-02", "2006/01/02", "2006.01.02"}
)

// ImportDidaHabits imports the workbook produced by Dida's habit export. Each
// worksheet is one habit; the first block contains metadata and the table below
// contains check-ins and optional mood/log entries.
func (s *Store) ImportDidaHabits(ctx context.Context, userID int64, data []byte, mode string) (*HabitImportResult, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("请选择 Dida 习惯导出文件")
	}
	if len(data) > maxDidaImportBytes {
		return nil, fmt.Errorf("Dida 导出文件不能超过 10MB")
	}
	sheets, err := parseDidaXLSX(data)
	if err != nil {
		return nil, err
	}
	if len(sheets) == 0 {
		return nil, fmt.Errorf("Dida 文件中没有可导入的习惯")
	}
	if len(sheets) > 200 {
		return nil, fmt.Errorf("一次最多导入 200 个习惯")
	}
	backup := &HabitBackup{Version: 1, ExportedAt: time.Now(), Habits: make([]HabitBackupHabit, 0, len(sheets))}
	sectionIDs := make(map[string]int64)
	checkinCount := 0
	for _, sheet := range sheets {
		if sheet.Habit == nil || sheet.Habit.Habit == nil {
			continue
		}
		if sheet.SectionName != "" && sectionIDs[sheet.SectionName] == 0 {
			id := int64(len(sectionIDs) + 1)
			sectionIDs[sheet.SectionName] = id
			backup.Sections = append(backup.Sections, &HabitSection{ID: id, Name: sheet.SectionName})
		}
		if sheet.SectionName != "" {
			sheet.Habit.Habit.SectionID = sectionIDs[sheet.SectionName]
		}
		checkinCount += len(sheet.Habit.Checkins)
		backup.Habits = append(backup.Habits, *sheet.Habit)
	}
	if checkinCount > maxDidaCheckins {
		return nil, fmt.Errorf("一次最多导入 20000 条打卡")
	}
	return s.ImportHabitsBackup(ctx, userID, backup, mode)
}

func parseDidaXLSX(data []byte) ([]didaSheet, error) {
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, fmt.Errorf("不是有效的 xlsx 文件: %w", err)
	}
	files := make(map[string]*zip.File, len(reader.File))
	for _, file := range reader.File {
		files[path.Clean(file.Name)] = file
	}
	readFile := func(name string) ([]byte, error) {
		file := files[path.Clean(name)]
		if file == nil {
			return nil, fmt.Errorf("xlsx 缺少文件 %s", name)
		}
		rc, err := file.Open()
		if err != nil {
			return nil, err
		}
		defer rc.Close()
		return io.ReadAll(io.LimitReader(rc, maxDidaImportBytes))
	}

	workbookData, err := readFile("xl/workbook.xml")
	if err != nil {
		return nil, err
	}
	var workbook xlsxWorkbookXML
	if err := xml.Unmarshal(workbookData, &workbook); err != nil {
		return nil, fmt.Errorf("解析 xlsx 工作簿失败: %w", err)
	}
	relsData, _ := readFile("xl/_rels/workbook.xml.rels")
	var rels xlsxRelationshipsXML
	if len(relsData) > 0 {
		_ = xml.Unmarshal(relsData, &rels)
	}
	relTargets := make(map[string]string, len(rels.Items))
	for _, rel := range rels.Items {
		relTargets[rel.ID] = rel.Target
	}

	var shared xlsxSharedStringsXML
	if sharedData, readErr := readFile("xl/sharedStrings.xml"); readErr == nil {
		_ = xml.Unmarshal(sharedData, &shared)
	}
	sharedStrings := make([]string, 0, len(shared.Items))
	for _, item := range shared.Items {
		sharedStrings = append(sharedStrings, strings.Join(item.Texts, ""))
	}

	sheets := make([]didaSheet, 0, len(workbook.Sheets))
	for index, sheet := range workbook.Sheets {
		target := relTargets[sheet.RID]
		if target == "" {
			target = fmt.Sprintf("worksheets/sheet%d.xml", index+1)
		}
		target = strings.TrimPrefix(path.Clean("/"+target), "/")
		if !strings.HasPrefix(target, "xl/") {
			target = path.Join("xl", target)
		}
		sheetData, err := readFile(target)
		if err != nil {
			continue
		}
		var worksheet xlsxWorksheetXML
		if err := xml.Unmarshal(sheetData, &worksheet); err != nil {
			continue
		}
		rows := xlsxRows(worksheet, sharedStrings)
		if parsed, ok := parseDidaSheet(sheet.Name, rows); ok {
			sheets = append(sheets, parsed)
		}
	}
	return sheets, nil
}

func xlsxRows(worksheet xlsxWorksheetXML, sharedStrings []string) [][]string {
	rows := make([][]string, 0, len(worksheet.Rows))
	for _, row := range worksheet.Rows {
		cells := make([]string, 0, len(row.Cells))
		for _, cell := range row.Cells {
			column := xlsxColumnIndex(cell.Ref)
			if column < 0 {
				column = len(cells)
			}
			for len(cells) <= column {
				cells = append(cells, "")
			}
			value := cell.Value
			switch cell.Type {
			case "inlineStr":
				value = strings.Join(cell.Inline.Texts, "")
			case "s":
				if index, err := strconv.Atoi(strings.TrimSpace(cell.Value)); err == nil && index >= 0 && index < len(sharedStrings) {
					value = sharedStrings[index]
				}
			}
			cells[column] = value
		}
		rows = append(rows, cells)
	}
	return rows
}

func xlsxColumnIndex(ref string) int {
	column := 0
	found := false
	for _, r := range ref {
		if r >= 'A' && r <= 'Z' {
			column = column*26 + int(r-'A'+1)
			found = true
			continue
		}
		if r >= 'a' && r <= 'z' {
			column = column*26 + int(r-'a'+1)
			found = true
			continue
		}
		break
	}
	if !found {
		return -1
	}
	return column - 1
}

func parseDidaSheet(sheetName string, rows [][]string) (didaSheet, bool) {
	if len(rows) == 0 {
		return didaSheet{}, false
	}
	fields := parseDidaFields(strings.Join(rows[0], "\n"))
	name := strings.TrimSpace(fields["习惯名称"])
	if name == "" {
		name = strings.TrimSpace(sheetName)
	}
	if name == "" {
		return didaSheet{}, false
	}
	goal, unit := parseDidaGoal(fields["目标"])
	frequency := parseDidaFrequency(fields["频率"])
	reminders := parseDidaReminders(fields["提醒时间"])
	sectionName := strings.TrimSpace(fields["所属分组"])
	if sectionName == "其他" {
		sectionName = ""
	}
	status := 0
	if strings.Contains(fields["习惯状态"], "归档") {
		status = 1
	}

	headerIndex := -1
	for index, row := range rows {
		if didaColumnIndex(row, "日期") >= 0 && (didaColumnIndex(row, "完成情况") >= 0 || didaColumnIndex(row, "完成量") >= 0) {
			headerIndex = index
			break
		}
	}
	checkins := make([]*HabitCheckin, 0)
	records := make([]*HabitRecord, 0)
	earliestStamp := 0
	if headerIndex >= 0 {
		header := rows[headerIndex]
		dateColumn := didaColumnIndex(header, "日期")
		timeColumn := didaColumnIndex(header, "时间")
		statusColumn := didaColumnIndex(header, "完成情况")
		valueColumn := didaColumnIndex(header, "完成量")
		moodColumn := didaColumnIndex(header, "心情")
		logColumn := didaColumnIndex(header, "日志")
		for _, row := range rows[headerIndex+1:] {
			dateText := didaCell(row, dateColumn)
			day, ok := parseDidaDate(dateText)
			if !ok {
				continue
			}
			stamp := stampOf(day)
			if earliestStamp == 0 || stamp < earliestStamp {
				earliestStamp = stamp
			}
			value := parseDidaFloat(didaCell(row, valueColumn))
			statusText := strings.TrimSpace(didaCell(row, statusColumn))
			checkinStatus := 0
			if strings.Contains(statusText, "完成") && !strings.Contains(statusText, "未完成") {
				checkinStatus = 2
			} else if strings.Contains(statusText, "未完成") {
				checkinStatus = 1
			} else if value >= goal && goal > 0 {
				checkinStatus = 2
			}
			if value > 0 || checkinStatus != 0 {
				checkin := &HabitCheckin{Stamp: stamp, Value: value, Goal: goal, Status: checkinStatus}
				if timeText := strings.TrimSpace(didaCell(row, timeColumn)); timeText != "" {
					if clock, err := time.ParseInLocation("15:04", timeText, time.Local); err == nil {
						at := time.Date(day.Year(), day.Month(), day.Day(), clock.Hour(), clock.Minute(), 0, 0, time.Local)
						checkin.CheckinTime = &at
					}
				}
				checkins = append(checkins, checkin)
			}
			content := strings.TrimSpace(didaCell(row, logColumn))
			if content != "" {
				records = append(records, &HabitRecord{Stamp: stamp, Content: content, Emoji: strings.TrimSpace(didaCell(row, moodColumn))})
			}
		}
	}
	if earliestStamp == 0 {
		earliestStamp = stampOf(time.Now())
	}
	habit := &Habit{
		Name: name, Icon: "😊", Color: "#97E38B", Goal: goal, Step: 1, Unit: unit,
		Frequency: frequency, Reminders: reminders, StartDate: earliestStamp, Status: status,
		Style: "check", ExDates: "[]", RecordEnable: len(records) > 0,
	}
	return didaSheet{
		SectionName: sectionName,
		Habit:       &HabitBackupHabit{Habit: habit, Checkins: checkins, Records: records},
	}, true
}

func parseDidaFields(text string) map[string]string {
	fields := make(map[string]string)
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "：", 2)
		if len(parts) != 2 {
			parts = strings.SplitN(line, ":", 2)
		}
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		if key != "" {
			fields[key] = value
		}
	}
	return fields
}

func parseDidaGoal(raw string) (float64, string) {
	raw = strings.TrimSpace(raw)
	match := didaGoalPattern.FindStringSubmatch(raw)
	goal := 1.0
	if len(match) > 1 {
		if parsed, err := strconv.ParseFloat(match[1], 64); err == nil && parsed > 0 {
			goal = parsed
		}
	}
	unit := "Count"
	if match != nil {
		rest := strings.TrimSpace(raw[len(match[0]):])
		if index := strings.Index(rest, "/"); index >= 0 {
			rest = rest[:index]
		}
		rest = strings.TrimSpace(rest)
		if rest != "" && rest != "次" {
			unit = rest
		}
	}
	return goal, unit
}

func parseDidaFrequency(raw string) string {
	raw = strings.TrimSpace(raw)
	freq := HabitFrequency{Type: "daily", Weekdays: []int{0, 1, 2, 3, 4, 5, 6}}
	switch {
	case strings.Contains(raw, "工作日"):
		freq.Weekdays = []int{1, 2, 3, 4, 5}
	case didaWeeklyPattern.MatchString(raw):
		match := didaWeeklyPattern.FindStringSubmatch(raw)
		freq.Type = "weekly"
		freq.DaysPerWeek, _ = strconv.Atoi(match[1])
		freq.Weekdays = nil
	case didaIntervalPattern.MatchString(raw):
		match := didaIntervalPattern.FindStringSubmatch(raw)
		freq.Type = "interval"
		freq.Interval, _ = strconv.Atoi(match[1])
		freq.Weekdays = nil
	case strings.Contains(raw, "周"):
		var weekdays []int
		for _, r := range raw {
			if day, ok := didaChineseWeekdays[r]; ok {
				seen := false
				for _, existing := range weekdays {
					if existing == day {
						seen = true
						break
					}
				}
				if !seen {
					weekdays = append(weekdays, day)
				}
			}
		}
		if len(weekdays) > 0 {
			freq.Weekdays = weekdays
		}
	}
	encoded, _ := json.Marshal(freq)
	return string(encoded)
}

func parseDidaReminders(raw string) string {
	matches := didaReminderPattern.FindAllStringSubmatch(raw, -1)
	values := make([]string, 0, len(matches))
	for _, match := range matches {
		hour, _ := strconv.Atoi(match[1])
		value := fmt.Sprintf("%02d:%s", hour, match[2])
		seen := false
		for _, existing := range values {
			if existing == value {
				seen = true
				break
			}
		}
		if !seen {
			values = append(values, value)
		}
	}
	if len(values) == 0 {
		return "[]"
	}
	encoded, _ := json.Marshal(values)
	return string(encoded)
}

func didaColumnIndex(header []string, name string) int {
	for index, value := range header {
		if strings.TrimSpace(value) == name {
			return index
		}
	}
	return -1
}

func didaCell(row []string, index int) string {
	if index < 0 || index >= len(row) {
		return ""
	}
	return row[index]
}

func parseDidaDate(raw string) (time.Time, bool) {
	raw = strings.TrimSpace(raw)
	for _, layout := range didaDateLayouts {
		if parsed, err := time.ParseInLocation(layout, raw, time.Local); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

func parseDidaFloat(raw string) float64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0
	}
	value, _ := strconv.ParseFloat(raw, 64)
	return value
}
