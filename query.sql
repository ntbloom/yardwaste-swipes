.headers on

ATTACH "databases/Db_SMS_TransHist.db" as history;

SELECT 
  TransactionHistory.transaction_date_time
  FROM history.TransactionHistory
  WHERE SUBSTR(TransactionHistory.transaction_date_time, 6,2) = "08";
  ORDER BY TransactionHistory.transaction_date_time DESC

;
