import requests
import re
import mysql.connector

mydb = mysql.connector.connect(
  host="localhost",
  user="adrian",
  password="P@sswr0d456",
  database="website"
)

mycursor = mydb.cursor()

mycursor.execute("SELECT * FROM links")

myresult = mycursor.fetchall()

data = {
        "username":"daniel",
        "password":"C@ughtm3napping123"
        }

for x in myresult:
  url1 = x[0]

  try:
    r1 = requests.get(url1,timeout=2)
    search = r1.text
    if (search.find('location.replace') != -1):
        match = re.findall("http(.*)\);",search)
        new_url = 'http' + match[0].rstrip(match[0][-1])
        r2 = requests.post(new_url,data=data,timeout=2)

    elif (search.find('opener.location') != -1):
        match = re.findall("http(.*);",search)
        new_url = 'http' + match[0].rstrip(match[0][-1])
        r2 = requests.post(new_url,data=data,timeout=2)
 
  except requests.exceptions.ReadTimeout:
    continue

