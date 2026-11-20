#!/vendor/bin/sh
# CleanBOX-H313: Auto-grant sideload, in-app update & storage permissions to all 3rd-party apps
for pkg in $(pm list packages -3 2>/dev/null | cut -d: -f2); do
    [ -z "$pkg" ] && continue
    cmd appops set "$pkg" REQUEST_INSTALL_PACKAGES allow 2>/dev/null
    pm grant "$pkg" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null
    pm grant "$pkg" android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null
done
