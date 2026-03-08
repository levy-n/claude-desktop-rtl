# claude-desktop-rtl

**תמיכת RTL (ימין-לשמאל) ב-Claude Desktop על Windows.**

מוסיף זיהוי אוטומטי של כיוון טקסט עברי וערבי ב-Claude Desktop — בלוקי קוד נשארים LTR.

## מה זה עושה

- מזהה אוטומטית טקסט בעברית/ערבית ומגדיר כיוון RTL
- בלוקי קוד, מתמטיקה ו-SVG נשארים LTR
- תיבת הקלט משנה כיוון דינמית
- MutationObserver לתגובות streaming
- שורד הפעלות מחדש (פאצ' קבוע ב-ASAR)

## התקנה

פשוט תריצו את זה ב-PowerShell:

```powershell
irm https://raw.githubusercontent.com/levy-n/claude-desktop-rtl/master/install.ps1 | iex
```

זהו. הסקריפט מוריד הכל, בודק תלויות, מתקין מה שחסר, ומפעיל את הפאצ' אוטומטית.

> **כבר הורדת את הריפו?** קליק ימני על `patch.ps1` → Run with PowerShell → בחר **1** (Install).

## תלויות

הסקריפט בודק ומתקין אוטומטית:

| תלות | נדרש | התקנה אוטומטית |
|------|-------|----------------|
| **Windows 10/11** | כן | — |
| **Claude Desktop** | כן | לא — התקן מ-[claude.ai/download](https://claude.ai/download) |
| **Node.js** | כן | כן — דרך `winget` |
| **@electron/asar** | כן | כן — דרך `npm install` מקומי |
| **PowerShell 5.1+** | כן | כלול ב-Windows |
| **Administrator** | כן | UAC אוטומטי |

**אם יש לך Node.js** — הסקריפט יזהה וישתמש.
**אם חסר Node.js** — הסקריפט מנסה להתקין דרך `winget`. אם לא זמין, מציג קישור.
**@electron/asar** — קודם בודק `node_modules` מקומי, אחר כך `npx`, ואם אין — מתקין אוטומטית.

## איך זה עובד

הפאצ'ר מבצע 4 פאזות:

| פאזה | מה | למה |
|------|-----|------|
| **0. תלויות** | בדיקת Node.js, asar, Claude Desktop — התקנת חסרות | הכנה לפני הפאצ' |
| **1. ASAR** | חילוץ, הזרקת RTL JavaScript, אריזה מחדש | לוגיקת RTL רצה בכל טעינת דף |
| **2. Hash** | חישוב hash חדש, החלפה ב-claude.exe | Electron מאמת תקינות ASAR |
| **3. Certificate** | יצירת certificate, החלפה ב-cowork-svc.exe, חתימה מחדש | שירות הרקע מאמת חתימת claude.exe |

## חלופה: שיטת DevTools (בלי פאצ')

1. צור `%APPDATA%\Claude\developer_settings.json` עם: `{"allowDevTools": true}`
2. הפעל מחדש את Claude Desktop
3. לחץ `Ctrl+Alt+I` → Console
4. הדבק את `scripts/devtools-inject.js` → Enter

**לשימוש חוזר:** DevTools → Sources → Snippets → New → הדבק → שמור כ-`RTL`.
בכל פעם: `Ctrl+Alt+I` → Sources → Snippets → קליק ימני על RTL → Run.

## הסרה

הרץ `patch.ps1` ובחר **2** (Restore Original State).

## אחרי עדכון Claude Desktop

עדכון מוחק את הפאצ'. פשוט הריצו שוב את `patch.ps1`.

## קרדיט

פרויקט זה מבוסס על [shraga100/claude-desktop-rtl-patch](https://github.com/shraga100/claude-desktop-rtl-patch) מאת [@shraga100](https://github.com/shraga100), שפיתח את גישת הזרקת ה-RTL, ארכיטקטורת הפאצ' ב-3 פאזות, וטכניקת החלפת ה-certificate עבור Claude Desktop.

פורק זה מוסיף ניהול תלויות אוטומטי, התקנה בשורה אחת, ושיפורים נוספים על הבסיס הזה.
