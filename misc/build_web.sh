rm -rf build
mkdir build

zip build/Wrinkle.love -r aud fnt img src main.lua -9

~/Downloads/node-v20.12.2-darwin-x64/bin/node ~/Downloads/lovejs-11/love.js/index.js --title "Wrinkle" build/Wrinkle.love -m 134217728 -c build/Wrinkle-web
cp misc/index.html build/Wrinkle-web

# scp -r build/Wrinkle-web/* art:/srv/wrinkle
