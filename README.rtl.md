# claude-desktop-rtl-natilevy

**תמיכת RTL (ימין-לשמאל) ב-Claude Desktop על Windows.**

מוסיף זיהוי אוטומטי של כיוון טקסט עברי וערבי ב-Claude Desktop — בלוקי קוד נשארים LTR.

## מה זה עושה

- מזהה אוטומטית טקסט בעברית/ערבית ומגדיר כיוון RTL
- בלוקי קוד, מתמטיקה ו-SVG נשארים LTR
- תיבת הקלט משנה כיוון דינמית
- MutationObserver לתגובות streaming
- שורד הפעלות מחדש (פאצ' קבוע ב-ASAR)

## התקנה מהירה

פתח PowerShell והרץ:

```powershell
irm https://raw.githubusercontent.com/natilevy/claude-desktop-rtl/main/install.ps1 | iex
```

## התקנה ידנית

1. הורד את הריפו
2. קליק ימני על `patch.ps1` → **Run with PowerShell**
3. בחר **1** (Install) ואשר עם **Y**
4. Claude Desktop יופעל מחדש עם תמיכת RTL

## דרישות

- Windows 10/11
- Claude Desktop (מ-Microsoft Store)
- Node.js (בשביל `npx asar`)
- הרשאות Administrator

## איך זה עובד

הפאצ'ר מבצע 3 פאזות:

| פאזה | מה | למה |
|------|-----|------|
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

## קרדיטים

- בהשראת [shraga100/claude-desktop-rtl-patch](https://github.com/shraga100/claude-desktop-rtl-patch)
- טכניקת ASAR header hash מקהילת Electron
- גישת החלפת Certificate מ-reverse engineering של שרשרת התקינות של Claude Desktop
