pyftsubset ChillRoundGothic_Regular.ttf \
  --output-file=../fnt/ChillRoundGothic_Regular_subset.ttf \
  --text=`cat ../src/*.lua | perl -CIO -pe 's/[\p{ASCII} \N{U+2500}-\N{U+257F}]//g'`
