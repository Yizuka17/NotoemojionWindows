# Advanced permissions and recovery

The system emoji font is normally in use by Windows components, so this project does not rely on deleting it while the desktop is running.

The font manager:

1. backs up the current `seguiemj.ttf`;
2. grants Administrators access to the target;
3. copies the replacement to a staged file;
4. verifies the staged SHA256;
5. queues `MoveFileEx(..., MOVEFILE_DELAY_UNTIL_REBOOT)`;
6. requests a Windows font-cache rebuild.

If Windows fails to apply the replacement, use the RESTORE option in `converter\windows_font_manager.bat`. The original font backup is kept at `C:\FontBackup\NotoEmojiOnWindows\seguiemj_original.ttf`.

For severe boot or shell problems, Safe Mode / Windows Recovery can be used to copy the backup back to `C:\Windows\Fonts\seguiemj.ttf`.
