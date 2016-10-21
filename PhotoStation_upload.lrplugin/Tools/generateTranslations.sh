# get all ZString from source code
cd ..
sed -r -n -f Tools/translationGen-sed.txt *.lua | sort | uniq > TranslatedStrings_en.txt

#get list of ZString paths in base translation 
awk 'BEGIN {FS="="} {print $1 "="}' TranslatedStrings_en.txt > TranslationPaths_en.txt

#check for duplicate ZStrings paths w/ different strings
uniq TranslationPaths_en.txt > TranslationPaths_en_unique.txt
diff TranslationPaths_en.txt TranslationPaths_en_unique.txt

if [ $? -ne 0 ] ; then
	echo "Inconsistent ZStrings in source code, stopping translation generation!"
	exit 1
fi

for lang in de es fr it ja ko nl pt sv zh_cn zh_tw ; do
	# save old target translation file
	cp TranslatedStrings_${lang}.txt TranslatedStrings_${lang}.txt.bak
	#get list of ZString paths in target translation, remove untranslated strings
	awk 'BEGIN {FS="="} {print $1 "="}' TranslatedStrings_${lang}.txt > TranslationPathsAll_${lang}.txt
	awk 'BEGIN {FS="="} $1 !~ /\/PleaseTranslate$/ {print $1 "="}' TranslationPathsAll_${lang}.txt > TranslationPaths_${lang}.txt
		 
	#get already translated ZStrings
	grep -F -f TranslationPaths_en.txt TranslatedStrings_${lang}.txt > TranslatedStrings_${lang}_ok.txt 
	#get missing translated ZStrings
	grep -F -v -f TranslationPaths_${lang}.txt TranslatedStrings_en.txt | awk 'BEGIN {FS="="} {print $1 "/PleaseTranslate=" $2}' > TranslatedStrings_${lang}_missing.txt 
	#get translated ZStrings to be removed
	grep -F -v -f TranslationPaths_en.txt TranslatedStrings_${lang}.txt | awk 'BEGIN {FS="="} $1 ~ /\/PleaseRemove$/ {print $0} $1 !~ /\/PleaseTranslate$/ && $1 !~ /\/PleaseRemove$/ {print $1 "/PleaseRemove=" $2}' > TranslatedStrings_${lang}_remove.txt 
	
	#combine all results
	cat TranslatedStrings_${lang}_ok.txt TranslatedStrings_${lang}_missing.txt TranslatedStrings_${lang}_remove.txt | sort > TranslatedStrings_${lang}.txt 
	#remove all language specific temporary files
	rm -f TranslationPathsAll_${lang}.txt TranslationPaths_${lang}.txt TranslatedStrings_${lang}_ok.txt TranslatedStrings_${lang}_missing.txt TranslatedStrings_${lang}_remove.txt TranslatedStrings_${lang}.txt.bak 
	#unix2dos ../TranslatedStrings_${lang}.txt
done
#remove all base language temporary files
rm -f TranslationPaths_en.txt TranslationPaths_en_unique.txt
#unix2dos ../TranslatedStrings_en.txt
