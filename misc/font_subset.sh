pyftsubset AaFendudu.ttf \
  --output-file=../fnt/AaFendudu_subset.ttf \
  --text=`cat ../src/*.lua | perl -CIO -pe 's/[\p{ASCII} \N{U+2500}-\N{U+257F}]//g'`
