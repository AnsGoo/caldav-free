package store

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"
)

type didaExportSheet struct {
	Name     string
	Metadata string
	Rows     [][]string
}

// ExportDidaHabits writes a workbook with one worksheet per habit. The layout
// mirrors the Dida habit export closely enough to be imported again by this
// project and by clients that understand the same metadata + table format.
func (s *Store) ExportDidaHabits(ctx context.Context, userID int64) ([]byte, error) {
	habits, err := s.ListHabits(ctx, userID, true)
	if err != nil {
		return nil, err
	}
	sections, err := s.ListHabitSections(ctx, userID)
	if err != nil {
		return nil, err
	}
	sectionNames := make(map[int64]string, len(sections))
	for _, section := range sections {
		sectionNames[section.ID] = section.Name
	}
	var checkins []*HabitCheckin
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("habit_id ASC, checkin_stamp ASC").Find(&checkins).Error; err != nil {
		return nil, err
	}
	var records []*HabitRecord
	if err := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("habit_id ASC, stamp ASC, id ASC").Find(&records).Error; err != nil {
		return nil, err
	}
	byHabitCheckins := make(map[int64][]*HabitCheckin)
	for _, checkin := range checkins {
		byHabitCheckins[checkin.HabitID] = append(byHabitCheckins[checkin.HabitID], checkin)
	}
	byHabitRecords := make(map[int64]map[int]*HabitRecord)
	for _, record := range records {
		if byHabitRecords[record.HabitID] == nil {
			byHabitRecords[record.HabitID] = make(map[int]*HabitRecord)
		}
		byHabitRecords[record.HabitID][record.Stamp] = record
	}
	sheets := make([]didaExportSheet, 0, len(habits))
	usedSheetNames := make(map[string]int)
	for _, habit := range habits {
		section := sectionNames[habit.SectionID]
		if section == "" {
			section = "其他"
		}
		status := "正常"
		if habit.Status == 1 {
			status = "已归档"
		}
		metadata := strings.Join([]string{
			"基本信息",
			"习惯名称：" + habit.Name,
			"习惯状态：" + status,
			"目标：" + formatDidaGoal(habit),
			"所属分组：" + section,
			"提醒时间：" + strings.Join(habitReminderTimes(habit.Reminders), "、"),
			"频率：" + didaFrequencyLabel(habit.Frequency),
		}, "\n")
		sheetName := sanitizeSheetName(habit.Name)
		if count := usedSheetNames[sheetName]; count > 0 {
			suffix := fmt.Sprintf(" (%d)", count+1)
			base := []rune(sheetName)
			limit := 31 - len([]rune(suffix))
			if len(base) > limit {
				base = base[:limit]
			}
			sheetName = string(base) + suffix
		}
		usedSheetNames[sanitizeSheetName(habit.Name)]++
		sheet := didaExportSheet{
			Name:     sheetName,
			Metadata: metadata,
			Rows:     [][]string{{"日期", "时间", "完成情况", "完成量", "心情", "日志"}},
		}
		checkinByStamp := make(map[int]*HabitCheckin, len(byHabitCheckins[habit.ID]))
		stamps := make(map[int]bool, len(byHabitCheckins[habit.ID]))
		for _, checkin := range byHabitCheckins[habit.ID] {
			checkinByStamp[checkin.Stamp] = checkin
			stamps[checkin.Stamp] = true
		}
		for stamp := range byHabitRecords[habit.ID] {
			stamps[stamp] = true
		}
		ordered := make([]int, 0, len(stamps))
		for stamp := range stamps {
			ordered = append(ordered, stamp)
		}
		sort.Ints(ordered)
		for _, stamp := range ordered {
			checkin := checkinByStamp[stamp]
			record := byHabitRecords[habit.ID][stamp]
			date, err := time.ParseInLocation(habitDayLayout, fmt.Sprintf("%08d", stamp), time.Local)
			if err != nil {
				continue
			}
			row := []string{date.Format("2006年01月02日"), "", "", "", "", ""}
			if checkin != nil {
				if checkin.CheckinTime != nil {
					row[1] = checkin.CheckinTime.In(time.Local).Format("15:04")
				}
				switch {
				case checkin.Status == 2 || checkin.Value >= checkin.Goal && checkin.Goal > 0:
					row[2] = "完成"
				case checkin.Status == 1:
					row[2] = "未完成"
				}
				row[3] = trimFloat(checkin.Value)
			}
			if record != nil {
				row[4] = record.Emoji
				row[5] = record.Content
			}
			sheet.Rows = append(sheet.Rows, row)
		}
		sheets = append(sheets, sheet)
	}
	return buildDidaXLSX(sheets)
}

func formatDidaGoal(habit *Habit) string {
	unit := strings.TrimSpace(habit.Unit)
	if unit == "" || unit == "Count" {
		unit = "次"
	}
	return fmt.Sprintf("%s %s/天", trimFloat(habit.Goal), unit)
}

func trimFloat(value float64) string {
	if value == float64(int64(value)) {
		return fmt.Sprintf("%d", int64(value))
	}
	return fmt.Sprintf("%.2f", value)
}

func habitReminderTimes(raw string) []string {
	var values []string
	_ = json.Unmarshal([]byte(raw), &values)
	out := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			out = append(out, value)
		}
	}
	return out
}

func didaFrequencyLabel(raw string) string {
	freq := parseHabitFrequency(raw)
	switch freq.Type {
	case "weekly":
		return fmt.Sprintf("每周 %d 天", freq.DaysPerWeek)
	case "interval":
		return fmt.Sprintf("每 %d 天", freq.Interval)
	default:
		if len(freq.Weekdays) >= 7 {
			return "每天"
		}
		if fmt.Sprint(freq.Weekdays) == fmt.Sprint([]int{1, 2, 3, 4, 5}) {
			return "工作日"
		}
		labels := []string{"日", "一", "二", "三", "四", "五", "六"}
		names := make([]string, 0, len(freq.Weekdays))
		for _, day := range freq.Weekdays {
			if day >= 0 && day < len(labels) {
				names = append(names, labels[day])
			}
		}
		if len(names) > 0 {
			return "每周" + strings.Join(names, "、")
		}
		return "每天"
	}
}

func sanitizeSheetName(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		name = "习惯"
	}
	replacer := strings.NewReplacer("[", "(", "]", ")", ":", "-", "*", "·", "?", "？", "/", "-", "\\", "-")
	name = replacer.Replace(name)
	if len([]rune(name)) > 31 {
		name = string([]rune(name)[:31])
	}
	return name
}

func buildDidaXLSX(sheets []didaExportSheet) ([]byte, error) {
	var buffer bytes.Buffer
	archive := zip.NewWriter(&buffer)
	write := func(name, content string) error {
		file, err := archive.Create(name)
		if err != nil {
			return err
		}
		_, err = file.Write([]byte(content))
		return err
	}
	contentTypes := strings.Builder{}
	contentTypes.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>`)
	for index := range sheets {
		contentTypes.WriteString(fmt.Sprintf(`<Override PartName="/xl/worksheets/sheet%d.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`, index+1))
	}
	contentTypes.WriteString(`</Types>`)
	if err := write("[Content_Types].xml", contentTypes.String()); err != nil {
		archive.Close()
		return nil, err
	}
	if err := write("_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`); err != nil {
		archive.Close()
		return nil, err
	}
	workbook := strings.Builder{}
	workbook.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>`)
	for index, sheet := range sheets {
		workbook.WriteString(fmt.Sprintf(`<sheet name="%s" sheetId="%d" r:id="rId%d"/>`, escapeXMLAttr(sheet.Name), index+1, index+1))
	}
	workbook.WriteString(`</sheets></workbook>`)
	if err := write("xl/workbook.xml", workbook.String()); err != nil {
		archive.Close()
		return nil, err
	}
	rels := strings.Builder{}
	rels.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`)
	for index := range sheets {
		rels.WriteString(fmt.Sprintf(`<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%d.xml"/>`, index+1, index+1))
	}
	rels.WriteString(`</Relationships>`)
	if err := write("xl/_rels/workbook.xml.rels", rels.String()); err != nil {
		archive.Close()
		return nil, err
	}
	for index, sheet := range sheets {
		var xml strings.Builder
		xml.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>`)
		rows := make([][]string, 0, len(sheet.Rows)+1)
		rows = append(rows, []string{sheet.Metadata})
		rows = append(rows, sheet.Rows...)
		for rowIndex, row := range rows {
			xml.WriteString(fmt.Sprintf(`<row r="%d">`, rowIndex+1))
			for column, value := range row {
				if value == "" {
					continue
				}
				ref := fmt.Sprintf("%c%d", 'A'+column, rowIndex+1)
				xml.WriteString(`<c r="` + ref + `" t="inlineStr"><is><t xml:space="preserve">` + escapeXMLText(value) + `</t></is></c>`)
			}
			xml.WriteString(`</row>`)
		}
		xml.WriteString(`</sheetData></worksheet>`)
		if err := write(fmt.Sprintf("xl/worksheets/sheet%d.xml", index+1), xml.String()); err != nil {
			archive.Close()
			return nil, err
		}
	}
	if err := archive.Close(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func escapeXMLText(value string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;").Replace(value)
}

func escapeXMLAttr(value string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&apos;").Replace(value)
}
