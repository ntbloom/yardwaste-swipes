.headers on
.mode csv

ATTACH "databases/Db_SMS_TransHist.db" as history;


SELECT 
  TransactionHistory.transaction_date_time,
  Person.first_name,
  Person.middle_name
  /*TransactionHistory.device_id*/

  FROM history.TransactionHistory
  INNER JOIN Person on Person.person_id = TransactionHistory.person_id

  WHERE 
    SUBSTR(TransactionHistory.transaction_date_time, 6,2) = "08"
    AND TransactionHistory.device_id = 22
    AND SUBSTR(Person.first_name, 1,2) != "NC"
    AND Person.person_id != 0
  ORDER BY TransactionHistory.transaction_history_id ASC
;

DETACH history;
