delimiter //

CREATE PROCEDURE add_user(IN new_user_name VARCHAR(16))
BEGIN
   DECLARE exist_user_name VARCHAR(16);
   SELECT user_name INTO exist_user_name
   FROM users
   WHERE user_name = new_user_name;
   IF exist_user_name IS NULL THEN
      INSERT INTO users (user_name) values (new_user_name);
   END IF;
END//

delimiter ;
