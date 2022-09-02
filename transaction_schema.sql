CREATE TABLE SystemSettings (
       section              VARCHAR(256) NOT NULL,
       item                 VARCHAR(256) NOT NULL,
       value                VARCHAR(256),
       PRIMARY KEY (section, item)
);
CREATE TABLE TransactionHistory (
       transaction_history_id INTEGER NOT NULL,
       transaction_date_time DATETIME,
       transaction_code_hi  INTEGER NOT NULL,
       transaction_code_lo  INTEGER NOT NULL,
       device_id            INTEGER,
       person_id            INTEGER,
       task_id              INTEGER,
       operator_id          INTEGER,
       encoded_id           VARCHAR(16),
       PRIMARY KEY (transaction_history_id)
);
CREATE INDEX PI_TransactionHistoryDateTime ON TransactionHistory
(
       transaction_date_time DESC
);
CREATE INDEX PI_TransactionHistoryPersonDateTime ON TransactionHistory
(
       person_id ASC,
       transaction_date_time ASC
);
CREATE INDEX idx_device_id ON TransactionHistory (device_id);
CREATE TRIGGER [delete_transaction_trigger] AFTER DELETE ON [TransactionHistory] FOR EACH ROW
BEGIN
   UPDATE SystemSettings SET value=value-1 WHERE section='current_values' AND item='transaction_count';
END;
CREATE TRIGGER [insert_transaction_trigger] AFTER INSERT ON [TransactionHistory] FOR EACH ROW
BEGIN
   UPDATE SystemSettings SET value=value+1 WHERE section='current_values' AND item='transaction_count';
END;
