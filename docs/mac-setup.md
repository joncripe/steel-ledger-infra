# EC2 Mac dev instance: one-time setup

The `mac2.metal` dev instance ([modules/ec2-mac-dev/](../modules/ec2-mac-dev/), provisioned per environment in [environments/dev/](../environments/dev/)) only opens port 22 in its security group — port 5900 (VNC) is intentionally never exposed. To reach the desktop over Screen Sharing, you tunnel VNC traffic through SSH. This only needs to be done once per instance; see the [README](../README.md#connecting-to-the-ec2-mac-dev-instance) for day-to-day connect/disconnect.

1. **Get the instance IP** (from `environments/dev`):
   ```
   terraform output mac_dev_public_ip
   ```
2. **First SSH connection** (no tunnel yet):
   ```
   ssh -i <path-to-key>.pem ec2-user@<public_ip>
   ```
3. **Set the `ec2-user` password** (used for VNC login):
   ```
   sudo passwd ec2-user
   ```
4. **Enable Screen Sharing:**
   ```
   sudo launchctl enable system/com.apple.screensharing
   sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
   sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -configure -allowAccessFor -allUsers -configure -restart -agent -privs -all
   ```
5. **Set a legacy VNC password.** macOS defaults to Apple-only auth, which most non-Apple VNC clients (e.g. TightVNC) can't use, so this step is required. The password must be **8 characters or fewer** — a VNC protocol limitation:
   ```
   sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes -setvncpw -vncpw "yourpw"
   ```
6. **Restart the service to apply it:**
   ```
   sudo launchctl unload /System/Library/LaunchDaemons/com.apple.screensharing.plist
   sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
   ```
7. **Reconnect with the tunnel** (leave this terminal open):
   ```
   ssh -i <path-to-key>.pem -L 5900:localhost:5900 ec2-user@<public_ip>
   ```
8. **Connect a VNC client** to `localhost::5900`, using the legacy VNC password from step 5 — not the `ec2-user` account password from step 3. **TightVNC is recommended**; RealVNC Connect's bundled client has an unrelated inbound-config bug that blocks this connection.

## Notes

- **Billing** is per Dedicated Host with a 24-hour minimum, regardless of whether the instance itself is stopped or started in between.
- **`terraform apply` can occasionally hang during host allocation** due to a known Terraform AWS provider bug related to `InsufficientHostCapacity`. If host creation is still running past ~10 minutes, that's the likely cause — it's not worth waiting out.
