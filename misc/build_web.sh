rm -rf build
mkdir build

zip build/Wrinkle.love -r aud fnt img src main.lua -9
# For quick iteration during development
# zip build/Wrinkle.love -r aud fnt img src main.lua -9 -x img/{background*,obj*} aud/*

~/Downloads/node-v20.12.2-darwin-x64/bin/node ~/Downloads/lovejs-11/love.js/index.js --title "Wrinkle" build/Wrinkle.love -m 134217728 -c build/Wrinkle-web
cp misc/index.html build/Wrinkle-web
perl -pi -w -e 's/(var et=e.touches;for\(var i=0;i<et.length;\+\+i\)\{var touch=et\[i\];touches\[touch.identifier\]=touch)\}/$1;touch.isChanged=0}/' build/Wrinkle-web/love.js

# scp -r build/Wrinkle-web/* art:/srv/wrinkle
