#!/bin/bash

# -i = case-insensitive, -E = extended regex for alternation

#Filtering lines by extracting all the issues and errors from the log
#grep command searches for patterns in files and displays matching lines
#-i will ignore case sensitivity
#-E enables extended regex
filtered_lines=$(grep -iE "ERROR|CRITICAL|FATAL" sys_log.txt) 

#split into one word per line
#Replacing spaces with a new line, easier to read
#remove punctuation of ":" from critical messages
#remove empty lines
#Each issue that got filtered will become its own token
tokens=$(echo "$filtered_lines" \
    | tr '[:space:]' '\n' \
    | sed 's/[^a-zA-Z0-9]//g' \
    | grep -v '^$')

#Counts the tokens occurences and sorting them from highest to lowest
#head -10 will take the first 10 tokens and put it into top10
top10=$(echo "$tokens" | sort | uniq -c | sort -rn | head -10)

echo "$top10"
#the top 10 tokens that got extracted will be saved into top10_critical text file, it is overwriting at the moment
echo "$top10" > top10_critical.txt
#shows the saved file content
cat top10_critical.txt

echo "Results saved to top10_critical.txt"

