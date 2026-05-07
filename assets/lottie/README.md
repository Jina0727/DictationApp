# Lottie animations

Drop the following `.json` files in this folder. They are loaded via
`Lottie.asset('assets/lottie/<name>.json')` from the app code.

| File | Used by | Recommended search keyword on lottiefiles.com |
|---|---|---|
| `celebration.json` | Daily session complete dialog | "trophy celebration", "confetti star", "success celebration" |
| `streak.json` (optional) | (future) streak milestone | "fire streak", "flame" |
| `level_up.json` (optional) | (future) milestone reached | "level up", "badge unlock" |

## How to grab one (free)

1. Visit https://lottiefiles.com — sign-up not required for free Lottie.
2. Search the keyword. Use the **Free** filter.
3. Open an animation, click the download button, choose **Lottie JSON**.
4. Rename the downloaded `.json` to the file name in the table above and place it in this folder.
5. `flutter pub get` is not needed; just hot-restart the app.

If the file is missing, the app falls back gracefully (no Lottie shown,
existing confetti effect still plays).
