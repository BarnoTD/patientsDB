PatientsDB - A synchronized Patient Data Storing app
==============
This App demonstrates database synchronization between devices using Google Drive. It works on macOS and iOS using SwiftUI.

The user signs in with their Google Account which takes them to the database: They can perform all CRUD operations on patients Data,
the app automatically pushes the database to Google Drive after Creating, Deleting or Updating Patients, User can Import the database on the cloud
by clicking the button "Import" on the toolbar, or do a manual upload with the cloud symbol button on the toolbar.

The Database is an sqlite file stored in the app container under "Data/Library/Application%20Support/PatientManager/db.sqlite"

# Pre-requisites to run this app
- Google Cloud Project with Drive API enabled and iOS+ credentials (Go to https://console.cloud.google.com, create a project, go to Credentails, and add Info.plist )
- keychain enabled
- Info.plist should include the GID Client ID (from credenitials):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string></string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>com.googleusercontent.apps.650418908425-sa0n9g3meaoobnoc8070d6cm3pp10imt</string>
			</array>
		</dict>
	</array>
	<key>GIDClientID</key>
	<string>650418908425-sa0n9g3meaoobnoc8070d6cm3pp10imt.apps.googleusercontent.com</string>
</dict>
</plist>
```
