# Get ONE link that opens MediSync (for your mam)

You will host three free things: the database (Atlas, done), the API (Render) and the website (Vercel).
The result is a link like  https://medisync-yourname.vercel.app  that opens on any phone or laptop.
Total time: about 30 minutes. You need a GitHub account.

## 1. Put the project on GitHub
1. Go to github.com -> New repository -> name it `medisync` -> Create (keep it Public or Private).
2. In VS Code terminal, in the folder that CONTAINS `medisync`'s files (the `medisync` folder):
   git init
   git add .
   git commit -m "MediSync"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/medisync.git
   git push -u origin main
   (.gitignore already keeps your .env password and node_modules out of GitHub.)

## 2. Allow the internet to reach your Atlas database
Atlas -> Network Access -> make sure 0.0.0.0/0 is in the list (you already added it).

## 3. Deploy the API on Render
1. render.com -> sign in with GitHub -> New -> Blueprint -> choose your `medisync` repo.
   (It reads render.yaml and creates "medisync-api".)
2. When it asks for the secret values, enter:
   MONGO_URI = your Atlas link, with /medisync before the ?  (same as in server\.env)
   CLIENT_URL = leave blank for now (you fill it in step 5)
   leave the other optional keys empty.
3. Wait until it says "Live". Copy the API address, for example  https://medisync-api.onrender.com
4. Test it: open  https://medisync-api.onrender.com/api/health  in Chrome. You should see an OK message.
5. Add the demo data ONE time: Render -> medisync-api -> Shell -> run:  npm run seed
   (If Shell is not available on the free plan, run  npm run seed  on your laptop. Your laptop .env already
   points to the same Atlas database, so the data is already there.)

## 4. Deploy the website on Vercel
1. vercel.com -> sign in with GitHub -> Add New -> Project -> pick the `medisync` repo.
2. Root Directory: client
3. Environment Variable:  VITE_API_URL = https://medisync-api.onrender.com   (your Render address, no slash at the end)
4. Deploy. You get a link like  https://medisync.vercel.app

## 5. Tell the API about the website
Render -> medisync-api -> Environment -> CLIENT_URL = https://medisync.vercel.app  -> Save (it restarts).

## 6. Share
Send the Vercel link to your mam. It opens the full app. On a phone, Chrome menu -> "Install app" /
"Add to Home screen" gives it an icon like WhatsApp.
Demo logins are on the login page ("Quick demo login"). To hide those buttons for the real launch, add
the Vercel variable VITE_DEMO = 0 and redeploy.

## Good to know
- Render free plan sleeps after 15 minutes. The FIRST open can take about 50 seconds. Open the link yourself
  1 minute before showing your mam.
- Video call works on the link because Vercel uses https.

## 7. Optional: the Flutter app as an APK that works anywhere
1. Open BUILD-APK.bat in Notepad and replace  https://YOUR-API.onrender.com/api  with your Render address (keep /api).
2. Double-click BUILD-APK.bat. When it finishes, send mobile\build\app\outputs\flutter-apk\app-release.apk
   to your phone (WhatsApp, Drive) and install it. It now talks to the online server, so no laptop or cable is needed.
