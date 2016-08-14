sed -r -n -f translationGen-sed.txt ../*.lua | sort | uniq > ../TranslatedStrings_en.txt
unix2dos ../TranslatedStrings_en.txt
