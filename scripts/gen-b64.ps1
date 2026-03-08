$js = Get-Content "src\rtl-renderer-inject.js" -Raw
$wrapped = "<script>`n" + $js + "`n</script>"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($wrapped)
$b64 = [Convert]::ToBase64String($bytes)
$b64
