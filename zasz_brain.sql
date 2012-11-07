CREATE DATABASE IF NOT EXISTS zasz;

use zasz;

CREATE TABLE IF NOT EXISTS users (
   user_id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
   user_name VARCHAR(16) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS user_messages (
   user_message_id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
   sender_user_name VARCHAR(16) NOT NULL,
   recipient_user_name VARCHAR(16) NOT NULL,
   message_text BLOB NOT NULL,
   message_time DATETIME,
   user_ip VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS user_events (
   user_event_id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
   user_name VARCHAR(16) NOT NULL,
   event_type VARCHAR(16) NOT NULL,
   event_date DATETIME,
   user_ip VARCHAR(64)
);
