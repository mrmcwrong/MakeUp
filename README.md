# MakeUp

- What are the system requirements?

    - A Windows computer with Windows 10+ installed.
    - An Android phone with Android 5+ installed OR an Android Virtual Device (AVD) emulator functioning with Android 5+.


- What dependencies need to be installed?
    - The Flutter SDK will need installed in VS Code.

    - The following dependencies will be installed with ```flutter pub get```:
        - shared_preferences
        - google_fonts
        - image_picker
        - path_provider
        - path
        - file_picker
        - open_filex
        - mime


- What are the step-by-step installation instructions?

#### 1. Install Flutter

-Download from flutter.dev/docs/get-started/install

-Follow the Windows install guide

-Run ```flutter doctor``` in terminal and fix any issues it flags


#### 2. Install Android Studio (for an android emulator)

-Download from developer.android.com/studio

-During setup, install Android SDK and create a virtual device [I chose the Pixel 9] OR use a physical Android/iOS device with USB debugging enabled


#### 3. Install Git (if not already installed)

-Download from git-scm.com


#### 4. Clone the repository

-Use the following commands in your terminal:

```
git clone https://github.com/mrmcwrong/MakeUp.git

cd MakeUp
```

#### 5. Install dependencies

-Use the following command in your terminal:
```
flutter pub get
```

#### 6. Accept Android licenses

-Use the following commands in your terminal:
```
flutter doctor --android-licenses
```
Press y to accept all.


#### 7. Open in VS Code


#### 8. Start an emulator

Choose one of the three following options:

-Open Android Studio > Device Manager > Play button on your virtual device

-Connect a physical device via USB

-Click the device button in the bottom right corner of the VS Code window (It probably says "Windows (windows-x64)" or something similar if you have not yet selected a device) and choose your AVD in the dropdown menu.

#### 9. Run the app

-In VS Code, press F5 or go to Run → Start Debugging OR in the terminal:
```
flutter run
```


- How can someone verify that the installation was successful?

When pressing F5 or using ```flutter run```, the app should be created in either your AVD, Windows, Chrome or Edge (depending on your default option or choice in the terminal).
