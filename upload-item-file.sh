#!/bin/bash
# exit script if any command fails

# Check that command line args are present

if [ $# -ne 2 ]
then
    echo "Usage: upload-item-file.sh <item> <full-path-to-file>"
    exit 1
fi

#modify BASE_URL, ACCESS_TOKEN, FILE_NAME and FILE_PATH according to your needs

BASE_URL='https://api.figsh.com/v2/account/articles'

ACCESS_TOKEN='dd24d2c8a7d8b9a7b3ad3a2bbed6774ce42470fee21813949ee68f1af0767aa74c531d40de68a90f78c99c4d9450711c74a7627b604f30101410aa30cba4a432'
FILE_NAME=$(basename "$2")
FILE_PATH="$2"
ITEM_ID=$1

# ####################################################################################

#Retrieve the file size and MD5 values for the item which needs to be uploaded
FILE_SIZE=$(du "${FILE_PATH}"| cut -f 1)
MD5=$(md5 -q "${FILE_PATH}")


printf "The item id is %s\n" $ITEM_ID

# Initiate new upload:
echo 'Initiate file upload -'
RESPONSE=$(curl -s -f -d '{"md5": "'${MD5}'", "name": "'${FILE_NAME}'", "size": '${FILE_SIZE}'}' -H 'Content-Type: application/json' -H 'Authorization: token '$ACCESS_TOKEN -X POST "$BASE_URL/$ITEM_ID/files")
echo $RESPONSE
# Retrieve file id
FILE_ID=$(echo "$RESPONSE" | sed -r "s/.*\/([0-9]+).*/\1/")
printf "file id is: %s\n" '$FILE_ID

exit 1

# Retrieve the upload url
echo 'Retrieving the upload URL...'
RESPONSE=$(curl -s -f -H 'Authorization: token '$ACCESS_TOKEN -X GET "$BASE_URL/$ITEM_ID/files/$FILE_ID")
echo $RESPONSE
UPLOAD_URL=$(echo "$RESPONSE" | sed -r 's/.*"upload_url":\s"([^"]+)".*/\1/')
printf "The upload URL is: %s\n" $UPLOAD_URL

# Retrieve the upload parts
RESPONSE=$(curl -s -f -H 'Authorization: token '$ACCESS_TOKEN -X GET "$UPLOAD_URL")
PARTS_SIZE=$(echo "$RESPONSE" | sed -r 's/"endOffset":([0-9]+).*/\1/' | sed -r 's/.*,([0-9]+)/\1/')
PARTS_SIZE=$(($PARTS_SIZE+1))

# Split item into needed parts
printf "Spliting the %s into parts\n" $FILE_PATH 
split -b$PARTS_SIZE $FILE_PATH part_ --numeric=1


# Retrive the number of parts
MAX_PART=$((($FILE_SIZE+$PARTS_SIZE-1)/$PARTS_SIZE))
printf "There are %s parts of size %s\n:" $MAX_PART $PARTS_SIZE

# Perform the PUT operation of parts
echo 'Perform the PUT operation of parts...'
for ((i=1; i<=$MAX_PART; i++))
do
    PART_VALUE='part_'$i
    if [ "$i" -le 9 ]
    then
        PART_VALUE='part_0'$i
    fi
    RESPONSE=$(curl -s -f -H 'Authorization: token '$ACCESS_TOKEN -X PUT "$UPLOAD_URL/$i" --data-binary @$PART_VALUE)
    printf "%d" $(( $i % 10 ))
done


# Complete upload
RESPONSE=$(curl -s -f -H 'Authorization: token '$ACCESS_TOKEN -X POST "$BASE_URL/$ITEM_ID/files/$FILE_ID")
printf "upload finished\n"

#remove the part files
rm part_*

# List all of the existing items
#RESPONSE=$(curl -s -f -H 'Authorization: token '$ACCESS_TOKEN -X GET "$BASE_URL")
#echo 'New list of items: '$RESPONSE
