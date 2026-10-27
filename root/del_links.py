import mysql.connector

mydb = mysql.connector.connect(
  host="localhost",
  user="adrian",
  password="P@sswr0d456",
  database="website"
)

mycursor = mydb.cursor()

mycursor.execute("TRUNCATE TABLE links")

mydb.close()
