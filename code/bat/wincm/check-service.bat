@echo off

for /F "tokens=3 delims=: " %%H in ('sc query "upguardd" ^| findstr "STATE"') do (
  if /I "%%H" NEQ "RUNNING" (
    echo "UpGuard Service not running"
    echo "Starting..."
    net start "upguardd"
  ) else (
    echo "UpGuard Service running"
  )
)


