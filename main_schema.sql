CREATE TABLE Area (
       area_id              INTEGER NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       delete_flag          INTEGER NOT NULL,
       caption              VARCHAR(64) NOT NULL,
       PRIMARY KEY (area_id)
);
CREATE TABLE AreaAccess (
       area_access_id       INTEGER NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       delete_flag          INTEGER NOT NULL,
       area_id              INTEGER NOT NULL,
       person_id            INTEGER NOT NULL,
       timezone_id          INTEGER NOT NULL,
       activation           DATETIME NOT NULL,
       expiration           DATETIME NOT NULL,
       blocked              BIT NOT NULL,
       toggle               BIT NOT NULL,
       lockdown             BIT NOT NULL,
       pass_through         BIT NOT NULL,
       PRIMARY KEY (area_access_id), 
       FOREIGN KEY (timezone_id)
                             REFERENCES Timezone  (timezone_id), 
       FOREIGN KEY (area_id)
                             REFERENCES Area  (area_id), 
       FOREIGN KEY (person_id)
                             REFERENCES Person  (person_id)
);
CREATE TABLE Badge (
       badge_id             INTEGER NOT NULL,
       modified_date_time   DATETIME,
       delete_flag          INTEGER NOT NULL,
       stamped_id           DECIMAL(19),
       encoded_id           DECIMAL(19) NOT NULL,
       issue_code           INTEGER,
       site_code            INTEGER,
       card_format_id       INTEGER,
       person_id            INTEGER NOT NULL,
       ev1_app_id           INTEGER DEFAULT 0,
       PRIMARY KEY (badge_id), 
       FOREIGN KEY (person_id)
                             REFERENCES Person  (person_id)
);
CREATE TABLE IF NOT EXISTS "BadgeHistory" (
  badge_hist_id         INTEGER NOT NULL,
  retired_date_time     DATETIME NOT NULL,
  expiration_date_time  DATETIME NOT NULL,  -- The lock (AD-275) self purges the voided card list, as voided cards expire.
  -- Start: Same columns as badge table.
  badge_id              INTEGER NOT NULL,
  stamped_id            DECIMAL(19),
  encoded_id            DECIMAL(19) NOT NULL,
  issue_code            INTEGER,
  site_code             INTEGER,
  card_format_id        INTEGER,
  person_id             INTEGER NOT NULL,
  ev1_app_id            INTEGER DEFAULT 0,
  -- End: Same columns as badge table.
  person_name           VARCHAR(100), -- Last name(32), first name(32) middle name(32).
  PRIMARY KEY (badge_hist_id)
);
CREATE TABLE DBChanges (
       change_id            INTEGER NOT NULL,
       db_changed           INTEGER NOT NULL,
       PRIMARY KEY (change_id)
);
CREATE TABLE Device (
       device_id            INTEGER NOT NULL,
       template_id			INTEGER NOT NULL,	-- references Template.db:Template.template_id
       date_created         DATETIME NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       hardware_type_id     INTEGER NOT NULL,	-- ???
       firmware_version     INTEGER,
       image_base_fn        VARCHAR(32),
       image_fn_ext	        VARCHAR(6),		-- jpg | jpeg | png | bmp | ico | ...
       controller_id		INTEGER,		-- appliance or Hub that device is connected to.  References Device.device_id
											-- value of 0 == the root master appliance
       area_id              INTEGER,
       channel              INTEGER,		-- channel of appliance it is ultimately connected to
											-- (for a wireless device, it's Hub's channel - won't be needed when/if we stop
											--  mapping wireless connections to the controllers addresses)
       network_address		VARCHAR(256) UNIQUE ON CONFLICT ABORT,
       port_address         INTEGER,		-- either a channel addr or a network port (or -for the future- a Hub connection number)
       caption              VARCHAR(64) NOT NULL,
       notes                VARCHAR(256),
       installed            INTEGER NOT NULL,
       lockdown_status		BOOLEAN DEFAULT 0,
       lockdown_time		DATETIME,
       delete_flag          INTEGER NOT NULL DEFAULT 0,
       notifications        INTEGER NOT NULL DEFAULT -1,
							-- -1:	use default settings
							--  0:	don't send notifications
							--  1:	use device specific notifications TBL::DeviceNotifications
       PRIMARY KEY (device_id), 
       FOREIGN KEY (area_id)	REFERENCES Area  (area_id)
      -- FOREIGN KEY (hardware_type_id)  REFERENCES Template.db:HardwareType  (hardware_type_id)	-- in different DB
);
CREATE TABLE PartType (
	part_type_id		INTEGER NOT NULL,
	lang_id				INTEGER NOT NULL,
	caption				VARCHAR(64) NOT NULL,		-- reader head, relay, contact, keypad, LED, IOchannel.OR.port, tamper switch(contact)

	PRIMARY KEY ( part_type_id, lang_id )
);
CREATE TABLE DeviceNotifications (
	device_id			INTEGER NOT NULL,	-- REFERENCES Device ( device_id ), no reference because ID 0 == global default
	transaction_code_hi	INTEGER NOT NULL,
	transaction_code_lo	INTEGER NOT NULL,
	PRIMARY KEY (device_id, transaction_code_hi, transaction_code_lo),
	FOREIGN KEY (transaction_code_hi, transaction_code_lo) REFERENCES TransactionCode (transaction_code_hi, transaction_code_lo)
);
CREATE INDEX idxDN_device_id ON DeviceNotifications ( device_id ASC );
CREATE TABLE DeviceAssembly (
	component_id		INTEGER NOT NULL PRIMARY KEY,
	device_id			INTEGER NOT NULL REFERENCES Device ( device_id ),
	part_type_id		INTEGER NOT NULL,	-- REFERENCES PartType ( part_type_id ),		sob! part_type_id is not unique
	component_num		INTEGER NOT NULL,
	caption				VARCHAR(64) NOT NULL COLLATE NOCASE
);
CREATE INDEX idxDA_device_id ON DeviceAssembly ( device_id ASC );
CREATE TABLE PartAttribute (  -- TMPLT.PartConfig
	attribute_id		INTEGER NOT NULL,
	part_type_id		INTEGER NOT NULL,	-- REFERENCES PartType ( part_type_id ),		sob! part_type_id is not unique
	lang_id				INTEGER NOT NULL,
	detail				CHAR(32) NOT NULL,		-- offline; default_state; resistor; ...

	PRIMARY KEY ( attribute_id, lang_id )
);
CREATE TABLE ComponentDesc (
	component_id	INTEGER NOT NULL REFERENCES DeviceAssembly ( component_id ),
	lang_id			INTEGER NOT NULL,
	caption			VARCHAR(64) NOT NULL COLLATE NOCASE,

	PRIMARY KEY ( component_id, lang_id )
);
CREATE TABLE ComponentConfig (
	component_id		INTEGER NOT NULL REFERENCES DeviceAssembly ( component_id ),
	attribute_id		INTEGER NOT NULL,	-- REFERENCES PartAttribute ( attribute_id ) ON UPDATE CASCADE,		sob! attribute_id is not unique
	attribute_value		INTEGER NOT NULL,
	user_editable		INTEGER NOT NULL,		--  0=no; 1=yes
	modified_date_time  DATETIME NOT NULL,

	PRIMARY KEY ( component_id, attribute_id )
);
CREATE INDEX idxCC_component_id ON ComponentConfig ( component_id ASC );
CREATE INDEX idxCC_attr_id ON ComponentConfig ( attribute_id ASC );
CREATE VIEW vwDvcAttrs AS
	SELECT da.device_id, da.part_type_id, da.component_num, da.caption, cc.*
	  FROM DeviceAssembly da INNER JOIN ComponentConfig cc ON cc.component_id = da.component_id
/* vwDvcAttrs(device_id,part_type_id,component_num,caption,component_id,attribute_id,attribute_value,user_editable,modified_date_time) */;
CREATE VIEW vwCompSubtype AS
	SELECT cc.component_id, cc.attribute_id, cc.attribute_value, substr(pa.detail,-5,-16) AS type
	  FROM PartAttribute pa
		INNER JOIN ComponentConfig cc ON cc.attribute_id = pa.attribute_id
	  WHERE pa.lang_id = 0 AND pa.detail LIKE '% type'
/* vwCompSubtype(component_id,attribute_id,attribute_value,type) */;
CREATE TABLE Task (		-- formerly OverrideType
	task_id			INTEGER NOT NULL,
	lang_id			INTEGER NOT NULL,
	caption			VARCHAR(80) NOT NULL,
	PRIMARY KEY ( task_id, lang_id )
);
CREATE TABLE DeviceResponse (
	-- tie triggers, transactions and responses to hardware
	device_response_id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	component_id		INTEGER NOT NULL REFERENCES DeviceAssembly ( component_id ),	-- device
	trigger_group		INTEGER,		-- -1=task; otherwise transaction code high
	trnx_task			INTEGER,
				-- if trigger_group=-1, then task_id (formerly override task)
				--                      else bitmask of transaction codes low
	active				BOOLEAN NOT NULL DEFAULT 1,		-- only one response of a response group can be active
	response_group_id	INTEGER,	-- REFERENCES Template.db:ResponseGroup ( response_group_id ),
	delete_flag			BOOLEAN NOT NULL DEFAULT 0,
	modified_date_time		DATETIME NOT NULL
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX idx_DeviceEvent ON DeviceResponse ( component_id, trigger_group, trnx_task );
CREATE VIEW vwDvcResponse AS
	SELECT  da.device_id, dr.* FROM DeviceAssembly da
		INNER JOIN DeviceResponse dr ON dr.component_id = da.component_id
/* vwDvcResponse(device_id,device_response_id,component_id,trigger_group,trnx_task,active,response_group_id,delete_flag,modified_date_time) */;
CREATE TABLE ResponseDesc (
	-- for response groups:  optional response to an event
	--		caption will be used as selection options in the UI
	-- for Task events:  the caption displayed in activity monitor and reports
	device_response_id		INTEGER NOT NULL REFERENCES DeviceResponse ( device_response_id ),
	lang_id					INTEGER NOT NULL,
	caption					VARCHAR(32) NOT NULL,
						-- ex:  unlock door; enter lockdown; resume normal operation, No REX with DOD Trigger, ...
	delete_flag			BOOLEAN NOT NULL DEFAULT 0,

	PRIMARY KEY ( device_response_id, lang_id )
);
CREATE TABLE TaskSchedule (
	schedule_id			INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	device_response_id	INTEGER NOT NULL REFERENCES DeviceResponse ( device_response_id ) ON UPDATE CASCADE,
	timezone_id			INTEGER NOT NULL DEFAULT 0 REFERENCES Timezone  (timezone_id) ON UPDATE CASCADE,
	card_enabled		BOOLEAN NOT NULL DEFAULT 0,
	modified_date_time		DATETIME NOT NULL
);
CREATE INDEX idx_TaskSchedResponse ON TaskSchedule ( device_response_id );
CREATE VIEW vwTaskSched
	AS SELECT dr.*, ts.schedule_id, ts.timezone_id, ts.card_enabled
	FROM DeviceResponse dr LEFT OUTER JOIN TaskSchedule ts ON ts.device_response_id = dr.device_response_id
/* vwTaskSched(device_response_id,component_id,trigger_group,trnx_task,active,response_group_id,delete_flag,modified_date_time,schedule_id,timezone_id,card_enabled) */;
CREATE TABLE ActionSequence (
	device_response_id	INTEGER NOT NULL REFERENCES DeviceResponse ( device_response_id ),
	sequence			INTEGER NOT NULL,
	action_id			INTEGER NOT NULL,	-- REFERENCES Template.db:Action ( action_id ) ON UPDATE CASCADE,
	action_argument		INTEGER,
	target_id			INTEGER NOT NULL REFERENCES DeviceAssembly ( component_id ),
							-- if we use a wait command, then must allow NULLs for target
	delete_flag			BOOLEAN NOT NULL DEFAULT 0,
	modified_date_time		DATETIME NOT NULL,

	PRIMARY KEY ( device_response_id, sequence )
);
CREATE TABLE EmailAlertSubject (
	notification_group_id	INTEGER,	-- REFERENCES NotificationGroup ( id ),		id not unique
	subject					VARCHAR(64) DEFAULT "bright blue alert notification",
	PRIMARY KEY (notification_group_id)
);
CREATE TABLE Holiday (
       holiday_id           INTEGER NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       delete_flag          INTEGER NOT NULL,
       holiday_start        DATETIME,
       holiday_stop         DATETIME,
       caption              VARCHAR(64) NOT NULL,
       notes                VARCHAR(256),
       PRIMARY KEY (holiday_id),
       UNIQUE (
              holiday_stop
       )
);
CREATE TABLE LocaleTimezone (
	locale_timezone_id   INTEGER NOT NULL,
	lang_id              INTEGER NOT NULL,
	caption              VARCHAR(64) NOT NULL,
	daylight_rule        VARCHAR(64),
	PRIMARY KEY ( locale_timezone_id, lang_id )
);
CREATE TABLE NotificationGroup (
	id					INTEGER NOT NULL,
	lang_id				INTEGER NOT NULL,
	caption				VARCHAR(32) NOT NULL,
	PRIMARY KEY (id, lang_id)
);
CREATE TABLE Operator (
       operator_id          INTEGER NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       delete_flag          INTEGER NOT NULL,
       user_id              VARCHAR(64) NOT NULL,
       password             VARCHAR(65) NOT NULL,
       security_group_id    INTEGER NOT NULL,
       last_name            VARCHAR(32),
       first_name           VARCHAR(32),
       middle_name          VARCHAR(32),
       guid                 VARCHAR(37),
       lang_code            VARCHAR(8) REFERENCES SupportedLanguages(lang_code) DEFAULT 'en_us',
       notes                VARCHAR(256),
       PRIMARY KEY (operator_id), 
       --FOREIGN KEY (security_group_id)
       --     REFERENCES SecurityGroup  (security_group_id),		SOB!, security_group_id not unique
       UNIQUE (user_id)
);
CREATE TABLE OperatorPreferences (
       operator_id          INTEGER NOT NULL,
       item                 VARCHAR(36),
       value                VARCHAR(48),
       PRIMARY KEY (operator_id, item),
       FOREIGN KEY (operator_id)
                             REFERENCES Operator  (operator_id)
);
CREATE TABLE Person (
       person_id            INTEGER NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       delete_flag          INTEGER NOT NULL,
       activation           DATETIME NOT NULL,
       expiration           DATETIME NOT NULL,
       last_name            VARCHAR(32),
       first_name           VARCHAR(32),
       middle_name          VARCHAR(32),
       keypad_id            INTEGER,  --VARCHAR(8),
       blocked              BIT NOT NULL,
       special_access       BIT NOT NULL,
       controlled_ap        BIT NOT NULL,
       notes                VARCHAR(256),
       user_field_1         VARCHAR(64),
       user_field_2         VARCHAR(64),
       user_field_3         VARCHAR(64),
       user_field_4         VARCHAR(64),
       user_field_5         VARCHAR(64),
       user_field_6         VARCHAR(64),
       first_person_in		BOOLEAN DEFAULT 0,
       PRIMARY KEY (person_id)
);
CREATE TABLE SecurityGroup (
	security_group_id    INTEGER NOT NULL,
	lang_id              INTEGER NOT NULL,
	caption              VARCHAR(64) NOT NULL,
	notes                VARCHAR(256),
	PRIMARY KEY ( security_group_id, lang_id )
);
CREATE TABLE SiteCode (
       sitecode             INTEGER NOT NULL,
       caption              VARCHAR(64) NOT NULL,
       PRIMARY KEY (sitecode)
);
CREATE TABLE SupportedLanguages (

	lang_id			INTEGER NOT NULL PRIMARY KEY,
	lang_code		CHAR(8) NOT NULL UNIQUE,
	installed		BIT NOT NULL DEFAULT 0,
	caption   		VARCHAR(64) NOT NULL,
	description		VARCHAR(64)

);
CREATE TABLE SystemSettings (
       section              VARCHAR(256) NOT NULL,
       item                 VARCHAR(256) NOT NULL,
       value                VARCHAR(256),
       PRIMARY KEY (section, item)
);
CREATE TABLE Timezone (
       timezone_id          INTEGER NOT NULL,
       modified_date_time   DATETIME NOT NULL,
       delete_flag          INTEGER NOT NULL,
       factory_set          BIT NOT NULL DEFAULT 0,
       visible              BIT NOT NULL DEFAULT 1,
       caption              VARCHAR(64) NOT NULL,
       notes                VARCHAR(256),
       PRIMARY KEY (timezone_id)
);
CREATE TABLE TimezoneInterval (
       timezone_interval_id INTEGER NOT NULL,
       timezone_id          INTEGER NOT NULL,
       interval_start       INTEGER NOT NULL,
       interval_stop        INTEGER NOT NULL,
       recurring            INTEGER NOT NULL,
       sun                  BIT NOT NULL,
       mon                  BIT NOT NULL,
       tue                  BIT NOT NULL,
       wed                  BIT NOT NULL,
       thu                  BIT NOT NULL,
       fri                  BIT NOT NULL,
       sat                  BIT NOT NULL,
       hol                  BIT NOT NULL,
       PRIMARY KEY (timezone_interval_id), 
       FOREIGN KEY (timezone_id)
                             REFERENCES Timezone  (timezone_id)
);
CREATE TABLE TransactionCode (
       transaction_code_hi  INTEGER NOT NULL,
       transaction_code_lo  INTEGER NOT NULL,
       card_transaction     BIT NOT NULL,
       device_type_id       INTEGER NOT NULL,
       foreground_color     VARCHAR(64),
       background_color     VARCHAR(64),
       image_name           VARCHAR(128),
       video_out_enable     BOOL DEFAULT 0,
       alarm_out_enable     BOOL DEFAULT 0,
       offline_transaction_id INTEGER DEFAULT 0,
       notification_group_id  INTEGER,	-- REFERENCES NotificationGroup ( id ),		id not unique
       email_alert_default  BOOL DEFAULT 0,
--       email_alert          BOOL DEFAULT 0,		moved to DeviceNotifications in v43
       allow_email_alert    BOOL DEFAULT 0,
       PRIMARY KEY (transaction_code_hi, transaction_code_lo)
       --FOREIGN KEY (transaction_code_hi)
       --        REFERENCES TransactionGroup  (transaction_code_hi), 		not unique
);
CREATE TABLE TransactionCode_I18N (
       transaction_code_hi    INTEGER NOT NULL,
       transaction_code_lo    INTEGER NOT NULL,
       lang_id                INTEGER NOT NULL,
       caption                VARCHAR(64) NOT NULL,
       PRIMARY KEY ( transaction_code_hi, transaction_code_lo, lang_id ),
       FOREIGN KEY (transaction_code_hi, transaction_code_lo)
               REFERENCES TransactionCode  (transaction_code_hi, transaction_code_lo)
);
CREATE TABLE TransactionGroup (
	transaction_code_hi  INTEGER NOT NULL,
	lang_id              INTEGER NOT NULL,
	caption              VARCHAR(64) NOT NULL,
	PRIMARY KEY ( transaction_code_hi, lang_id )
);
CREATE TABLE VSSEventSettings3VR (
   guid             VARCHAR(64) NOT NULL,
   transaction_code_hi    INTEGER NOT NULL,
   field_type		INTEGER NOT NULL, -- 0=event definition type, 1=event description, 2=person name, 3=door name, 4=badge id
   display_type     INTEGER,          -- -1= not displayed, 0=string, 1=number, 2=datetime, 3=enumerated data
   format           VARCHAR(32),
   position         INTEGER,          -- display position in 3vr gui, 0=generic event description, 1=first, 2=second, 3=third, ...
   PRIMARY KEY (guid)
   --FOREIGN KEY (transaction_code_hi) REFERENCES TransactionGroup (transaction_code_hi)
);
CREATE TABLE VSSEventSettings3VR_I18N (
       guid       VARCHAR(64) NOT NULL REFERENCES VSSEventSettings3VR ( guid ),
       lang_id    INTEGER NOT NULL,
       caption    VARCHAR(64) NOT NULL,
       PRIMARY KEY ( guid, lang_id )
);
CREATE INDEX AK_AreaCaption ON Area
(
       caption ASC
);
CREATE UNIQUE INDEX AK_HolidayRangeCaption ON Holiday
(
       holiday_stop ASC
);
CREATE UNIQUE INDEX AK_OperatorLogin ON Operator
(
       user_id ASC
);
CREATE INDEX AK_TimezoneCaption ON Timezone
(
       caption ASC
);
CREATE INDEX PI_AreaAccessChange ON AreaAccess
(
       person_id ASC,
       delete_flag ASC,
       modified_date_time ASC
);
CREATE INDEX PI_AreaAccessPersons ON AreaAccess
(
       area_id ASC,
       person_id ASC
);
CREATE INDEX PI_AreaChange ON Area
(
       modified_date_time ASC,
       delete_flag ASC
);
CREATE INDEX PI_BadgeEncoded ON Badge
(
       encoded_id ASC,
       issue_code ASC
);
CREATE INDEX PI_BadgeStamped ON Badge
(
       stamped_id ASC,
       issue_code ASC
);
CREATE INDEX PI_DeletePerson ON Badge
(
       delete_flag ASC,
       person_id ASC
);
CREATE INDEX PI_DeviceChange ON Device
(
       modified_date_time ASC,
       delete_flag ASC
);
CREATE INDEX PI_HolidayRangeChange ON Holiday
(
       modified_date_time ASC,
       delete_flag ASC
);
CREATE INDEX PI_PersonChange ON Person
(
       delete_flag ASC,
       modified_date_time ASC
);
CREATE INDEX PI_PersonName ON Person
(
       last_name ASC,
       first_name ASC,
       middle_name ASC
);
CREATE INDEX PI_TimezoneChange ON Timezone
(
       modified_date_time ASC,
       delete_flag ASC
);
CREATE INDEX XIF1TimezoneInterval ON TimezoneInterval
(
       timezone_id ASC
);
CREATE INDEX XIF1TransactionCode ON TransactionCode
(
       device_type_id ASC
);
CREATE INDEX XIF2Operator ON Operator
(
       security_group_id ASC
);
CREATE INDEX XIF2TransactionCode ON TransactionCode
(
       transaction_code_hi ASC
);
CREATE TRIGGER [delete_sitecode_trigger] AFTER DELETE ON [SiteCode] FOR EACH ROW
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
end;
CREATE TRIGGER [insert_access_trigger] AFTER INSERT On [AreaAccess] FOR EACH ROW
BEGIN
   -- db ver 5 to ver 6
   --UPDATE Badge SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE NEW.person_id=Badge.person_id;
   UPDATE Person SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE Person.person_id = NEW.person_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
END;
CREATE TRIGGER [insert_area_trigger] AFTER INSERT On [Area] FOR EACH ROW
BEGIN 
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
END;
CREATE TRIGGER [insert_badge_trigger] AFTER INSERT On [Badge] FOR EACH ROW
WHEN NEW.encoded_id<>''
BEGIN 
   UPDATE PERSON SET modified_date_time=DATETIME('NOW','LOCALTIME') where person_id = (SELECT person_id FROM Badge where badge_id=NEW.badge_id) AND delete_flag = 0;
   UPDATE AreaAccess SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE AreaAccess.person_id = NEW.person_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [insert_holiday_trigger] AFTER INSERT On [Holiday] FOR EACH ROW
BEGIN 
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [insert_sitecode_trigger] AFTER INSERT ON [SiteCode] FOR EACH ROW
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
end;
CREATE TRIGGER [insert_timezoneinterval_trigger] AFTER INSERT On [TimezoneInterval] FOR EACH ROW
BEGIN
   UPDATE Timezone SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE timezone_id = NEW.timezone_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_DST_trigger] AFTER UPDATE OF [value] On [SystemSettings] FOR EACH ROW
WHEN OLD.section = 'LocaleTimezone' AND OLD.item='daylight_rule' AND NEW.value <> OLD.value
BEGIN 
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
END;
CREATE TRIGGER [update_access_trigger] AFTER UPDATE OF [delete_flag], [area_id], [person_id], [timezone_id], [activation], [expiration], [blocked], [toggle], [pass_through], [lockdown] On [AreaAccess] FOR EACH ROW
WHEN NEW.delete_flag <> OLD.delete_flag OR NEW.area_id <> OLD.area_id 
OR NEW.person_id <> OLD.person_id OR NEW.timezone_id <> OLD.timezone_id 
OR NEW.activation <> OLD.activation OR NEW.expiration <> OLD.expiration 
OR NEW.blocked <> OLD.blocked OR NEW.toggle <> OLD.toggle
OR NEW.pass_through <> OLD.pass_through OR NEW.lockdown <> OLD.lockdown
BEGIN 
	-- TODO:  this 1st line should be set in the Update stmt to begin with
   UPDATE AreaAccess SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE area_access_id=NEW.area_access_id AND (OLD.delete_flag = 0 OR NEW.delete_flag = 0);
   UPDATE Person SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE NEW.person_id=Person.person_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
END;
CREATE TRIGGER [update_antipbtime_trigger] AFTER UPDATE OF [value] On [SystemSettings] FOR EACH ROW
WHEN OLD.section = 'global' AND OLD.item='antipassback_time' AND NEW.value <> OLD.value
BEGIN 
   UPDATE ComponentConfig SET attribute_value=NEW.value, modified_date_time=DATETIME('NOW','LOCALTIME') WHERE attribute_id IN (SELECT attribute_id FROM PartAttribute WHERE detail = 'antipassback time');
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
END;
CREATE TRIGGER [update_area_trigger] AFTER UPDATE OF [area_id], [delete_flag] On [Area] FOR EACH ROW
WHEN NEW.delete_flag <> OLD.delete_flag 
BEGIN 
	-- TODO:  this 1st line should be set in the Update stmt to begin with
   UPDATE Area SET modified_date_time = DATETIME('NOW','LOCALTIME') WHERE area_id=NEW.area_id;
   UPDATE AreaAccess SET delete_flag = NEW.delete_flag, modified_date_time = DATETIME('NOW','LOCALTIME') WHERE delete_flag<>NEW.delete_flag AND area_id=NEW.area_id;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_badge_trigger] AFTER UPDATE OF [delete_flag], [stamped_id], [encoded_id], [issue_code], [site_code], [card_format_id] On [Badge] FOR EACH ROW
WHEN NEW.ENCODED_ID <> OLD.ENCODED_ID OR NEW.DELETE_FLAG <> OLD.DELETE_FLAG OR NEW.ISSUE_CODE <> OLD.ISSUE_CODE OR NEW.SITE_CODE <> OLD.SITE_CODE OR NEW.CARD_FORMAT_ID <> OLD.CARD_FORMAT_ID 
BEGIN 
	-- TODO:  this 1st line should be set in the Update stmt to begin with
   UPDATE BADGE SET modified_date_time=DATETIME('NOW','LOCALTIME') where badge_id=NEW.badge_id AND (OLD.delete_flag = 0 OR NEW.delete_flag = 0);
   UPDATE PERSON SET modified_date_time=DATETIME('NOW','LOCALTIME') where person_id = (SELECT person_id FROM Badge where badge_id=NEW.badge_id) AND delete_flag = 0;
   UPDATE AreaAccess SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE NEW.person_id=AreaAccess.person_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_card_tech_trigger] AFTER UPDATE OF [value] ON [SystemSettings] FOR EACH ROW
WHEN OLD.section = 'card_tech' AND NEW.value <> OLD.value
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [new_device_trigger] BEFORE INSERT ON [Device]
FOR EACH ROW WHEN (NEW.hardware_type_id > 0 AND NEW.delete_flag = 0)
BEGIN
	INSERT INTO Area (area_id, modified_date_time, delete_flag, caption) VALUES (NEW.area_id, NEW.modified_date_time, 0, NEW.caption);
END;
CREATE TRIGGER [update_device_trigger] AFTER UPDATE OF [area_id], [channel], [network_address], [port_address], [Installed] On [Device]
FOR EACH ROW
WHEN ( NEW.area_id<>OLD.area_id OR
OLD.channel<>NEW.channel OR OLD.port_address<>NEW.port_address OR OLD.network_address<>NEW.network_address OR
NEW.installed<>OLD.Installed )
begin
   UPDATE Area SET delete_flag = NEW.delete_flag, modified_date_time = DATETIME('NOW','LOCALTIME') WHERE delete_flag<>NEW.delete_flag AND area_id=NEW.area_id;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_device_name_trigger] AFTER UPDATE OF [caption] ON [Device]
FOR EACH ROW WHEN (NEW.caption <> OLD.caption)
BEGIN
   UPDATE Area SET caption = NEW.caption, modified_date_time = DATETIME('NOW','LOCALTIME') WHERE area_id = NEW.area_id;
END;
CREATE TRIGGER [flag_delete_device_trigger] BEFORE UPDATE OF [delete_flag] ON [Device]
FOR EACH ROW WHEN (NEW.delete_flag > 0 AND (OLD.installed > 0 OR OLD.network_address NOT NULL))
BEGIN
   UPDATE Device SET delete_flag = 1, installed = 0, network_address = NULL, modified_date_time = DATETIME('NOW','LOCALTIME') WHERE device_id = NEW.device_id;
   UPDATE Area SET delete_flag = NEW.delete_flag, modified_date_time = DATETIME('NOW','LOCALTIME') WHERE delete_flag<>NEW.delete_flag AND area_id=NEW.area_id;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_component_attr] AFTER UPDATE OF [attribute_value] On [ComponentConfig] FOR EACH ROW
WHEN NEW.attribute_value <> OLD.attribute_value
  AND -- device is installed
  1 IS (SELECT d.installed FROM vwDvcAttrs vda INNER JOIN Device d ON d.device_id = vda.device_id WHERE vda.component_id = NEW.component_id)
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [insert_component_attr] AFTER INSERT On [ComponentConfig] FOR EACH ROW
WHEN -- device is installed
  1 IS (SELECT d.installed FROM vwDvcAttrs vda INNER JOIN Device d ON d.device_id = vda.device_id WHERE vda.component_id = NEW.component_id)
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_dvc_response] AFTER UPDATE OF [component_id], [trigger_group], [trnx_task], [active], [delete_flag] On [DeviceResponse] FOR EACH ROW
WHEN ( NEW.delete_flag <> OLD.delete_flag OR NEW.active <> OLD.active OR NEW.component_id <> OLD.component_id
  OR NEW.trigger_group <> OLD.trigger_group OR NEW.trnx_task <> OLD.trnx_task )
  AND -- device is installed
   1 IS (SELECT d.installed FROM vwDvcResponse vdr INNER JOIN Device d ON d.device_id = vdr.device_id WHERE vdr.device_response_id = NEW.device_response_id)
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_task_sched] AFTER UPDATE OF [device_response_id], [timezone_id], [card_enabled] On [TaskSchedule] FOR EACH ROW
WHEN ( NEW.device_response_id <> OLD.device_response_id OR NEW.timezone_id <> OLD.timezone_id OR NEW.card_enabled <> OLD.card_enabled )
  AND -- device is installed and the response is active
  ( 1 IS (SELECT vdr.active FROM vwDvcResponse vdr INNER JOIN Device d ON d.device_id = vdr.device_id AND d.installed = 1 WHERE vdr.device_response_id = NEW.device_response_id)
 -- device is installed and the OLD response was active  (probably not relevant)
  OR 1 IS (SELECT vdr.active FROM vwDvcResponse vdr INNER JOIN Device d ON d.device_id = vdr.device_id AND d.installed = 1 WHERE vdr.device_response_id = OLD.device_response_id) )
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [insert_task_sched] AFTER INSERT On [TaskSchedule] FOR EACH ROW
WHEN  -- device is installed and the response is active
   1 IS (SELECT vdr.active FROM vwDvcResponse vdr INNER JOIN Device d ON d.device_id = vdr.device_id AND d.installed = 1 WHERE vdr.device_response_id = NEW.device_response_id)
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_action_sequence] AFTER UPDATE OF [sequence], [action_id], [action_argument], [target_id], [delete_flag] On [ActionSequence] FOR EACH ROW
WHEN ( NEW.delete_flag <> OLD.delete_flag OR NEW.sequence <> OLD.sequence OR NEW.action_id <> OLD.action_id
 OR NEW.action_argument <> OLD.action_argument OR NEW.target_id <> OLD.target_id ) AND
 -- target device is installed
 ( 1 IS (SELECT d.installed FROM vwDvcAttrs vda INNER JOIN Device d ON d.device_id = vda.device_id WHERE vda.component_id = NEW.target_id)
 -- triggering device is installed and this response is active
  OR 1 IS (SELECT vdr.active FROM vwDvcResponse vdr INNER JOIN Device d ON d.device_id = vdr.device_id AND d.installed = 1 WHERE vdr.device_response_id = NEW.device_response_id) )
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [insert_action_sequence] AFTER INSERT On [ActionSequence] FOR EACH ROW
WHEN -- target device is installed
 ( 1 IS (SELECT d.installed FROM vwDvcAttrs vda INNER JOIN Device d ON d.device_id = vda.device_id WHERE vda.component_id = NEW.target_id)
 -- triggering device is installed and this response is active
  OR 1 IS (SELECT vdr.active FROM vwDvcResponse vdr INNER JOIN Device d ON d.device_id = vdr.device_id AND d.installed = 1 WHERE vdr.device_response_id = NEW.device_response_id) )
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_holiday_trigger] AFTER UPDATE OF [delete_flag], [holiday_start], [holiday_stop] On [Holiday] FOR EACH ROW
WHEN NEW.delete_flag <> OLD.delete_flag OR NEW.holiday_start <> OLD.holiday_start OR NEW.holiday_stop <> OLD.holiday_stop
BEGIN
	-- TODO:  this 1st line should be set in the Update stmt to begin with
   UPDATE Holiday SET modified_date_time=DATETIME('NOW','LOCALTIME') where holiday_id=NEW.holiday_id AND (OLD.delete_flag = 0 OR NEW.delete_flag = 0);
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_person_access] AFTER UPDATE OF [activation], [expiration], [delete_flag], [blocked], [keypad_id] On [Person] FOR EACH ROW
WHEN NEW.person_id<>0 AND (NEW.activation<>OLD.activation OR NEW.expiration<>OLD.expiration 
OR NEW.delete_flag<>OLD.delete_flag OR NEW.keypad_id<>OLD.keypad_id)
begin
	-- TODO:  this 1st line should be set in the Update stmt to begin with
   UPDATE Person SET modified_date_time=DATETIME('NOW','LOCALTIME') where person_id=NEW.person_id AND (OLD.delete_flag = 0 OR NEW.delete_flag = 0);
   --2008-09-19 MRC fixed AreaAccess to only update records where AreaAccess.delete_flag=0 to prevent
   --records from becoming un-deleted
   UPDATE AreaAccess SET activation=NEW.activation, expiration=NEW.expiration, modified_date_time=DATETIME('NOW','LOCALTIME'),
      delete_flag=NEW.delete_flag
      WHERE (activation<>NEW.activation OR expiration<>NEW.expiration 
      OR AreaAccess.delete_flag<>NEW.delete_flag)
      AND AreaAccess.delete_flag=0 AND AreaAccess.person_id=NEW.person_id;
   --2008-09-19 MRC fixed Badge to only update records where Badge.delete_flag=0 to prevent
   --records from becoming un-deleted
   UPDATE Badge SET delete_flag=NEW.delete_flag, modified_date_time=DATETIME('NOW','LOCALTIME') WHERE Badge.delete_flag=0 AND Badge.delete_flag<>NEW.delete_flag AND person_id=NEW.person_id;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_person_badge_trigger] AFTER UPDATE OF [blocked], [special_access], [controlled_ap], [first_person_in] On [Person] FOR EACH ROW
WHEN NEW.blocked<>OLD.blocked OR NEW.special_access<>OLD.special_access OR 
NEW.controlled_ap<>OLD.controlled_ap OR NEW.first_person_in<>OLD.first_person_in
begin
	-- TODO:  this 1st line should be set in the Update stmt to begin with
   UPDATE Person SET modified_date_time=DATETIME('NOW','LOCALTIME') where person_id=NEW.person_id AND (OLD.delete_flag = 0 OR NEW.delete_flag = 0);
   UPDATE Badge SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE NEW.person_id=Badge.person_id AND delete_flag = 0;
   UPDATE AreaAccess SET modified_date_time=DATETIME('NOW','LOCALTIME') where AreaAccess.person_id=NEW.person_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_sitecode_trigger] AFTER UPDATE OF [sitecode] ON [SiteCode] FOR EACH ROW
WHEN NEW.sitecode <> OLD.sitecode
BEGIN
   UPDATE DBChanges SET db_changed=1 WHERE change_id=1 AND db_changed=0;
end;
CREATE TRIGGER [update_timezone_trigger] AFTER UPDATE OF [delete_flag] On [Timezone] FOR EACH ROW
WHEN NEW.delete_flag<>OLD.delete_flag AND NEW.delete_flag=1
BEGIN
   UPDATE AreaAccess SET timezone_id=0, modified_date_time = DATETIME('NOW','LOCALTIME') WHERE timezone_id=NEW.timezone_id;
--    UPDATE EventTrigger SET timezone_id=0 WHERE timezone_id=NEW.timezone_id;
--    UPDATE OverrideTask SET timezone_id=0 WHERE timezone_id=NEW.timezone_id;
 	-- TODO:  this next line should be set in the Update stmt to begin with
  UPDATE Timezone SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE timezone_id=NEW.timezone_id AND (OLD.delete_flag = 0 OR NEW.delete_flag = 0);
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [update_timezoneinterval_trigger] AFTER UPDATE OF [timezone_id], [interval_start], [interval_stop], [recurring], [sun], [mon], [tue], [wed], [thu], [fri], [sat], [hol] On [TimezoneInterval] FOR EACH ROW
WHEN NEW.timezone_id<>OLD.timezone_id OR NEW.interval_start<>OLD.interval_start OR 
NEW.interval_stop<>OLD.interval_stop OR NEW.recurring<>OLD.recurring OR 
NEW.sun<>OLD.sun OR NEW.mon<>OLD.mon OR NEW.tue<>OLD.tue OR NEW.wed<>OLD.wed OR 
NEW.thu<>OLD.thu OR NEW.fri<>OLD.fri OR NEW.sat<>OLD.sat OR NEW.sun<>OLD.sun OR 
NEW.hol<>OLD.hol
BEGIN
   UPDATE Timezone SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE timezone_id = NEW.timezone_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [delete_timezoneinterval_trigger] AFTER DELETE ON [TimezoneInterval] FOR EACH ROW
BEGIN
   UPDATE Timezone SET modified_date_time=DATETIME('NOW','LOCALTIME') WHERE timezone_id = OLD.timezone_id AND delete_flag = 0;
   UPDATE DBChanges SET db_changed=1 WHERE change_id = 1 AND db_changed=0;
END;
CREATE TRIGGER [delete_person] AFTER DELETE ON [Person] FOR EACH ROW
BEGIN
	DELETE FROM Badge WHERE person_id = OLD.person_id;
	DELETE FROM BadgeHistory WHERE person_id = OLD.person_id;
	DELETE FROM AreaAccess WHERE person_id = OLD.person_id;
END;
CREATE TRIGGER [delete_device] AFTER DELETE ON [Device] FOR EACH ROW
BEGIN
	DELETE FROM ResponseDesc WHERE device_response_id IN (SELECT device_response_id FROM vwDvcResponse WHERE device_id = OLD.device_id);
	DELETE FROM TaskSchedule WHERE device_response_id IN (SELECT device_response_id FROM vwDvcResponse WHERE device_id = OLD.device_id);
	DELETE FROM ActionSequence WHERE device_response_id IN (SELECT device_response_id FROM vwDvcResponse WHERE device_id = OLD.device_id);
	DELETE FROM ComponentConfig WHERE component_id IN (SELECT component_id FROM DeviceAssembly WHERE device_id = OLD.device_id);
	DELETE FROM DeviceResponse WHERE component_id IN (SELECT component_id FROM DeviceAssembly WHERE device_id = OLD.device_id);
	DELETE FROM ComponentDesc WHERE component_id IN (SELECT component_id FROM DeviceAssembly WHERE device_id = OLD.device_id);
	DELETE FROM DeviceAssembly WHERE device_id = OLD.device_id;
	DELETE FROM AreaAccess WHERE area_id = OLD.area_id;
	DELETE FROM Area WHERE area_id = OLD.area_id;
END;
CREATE TRIGGER [db_changed_trigger]  
	AFTER UPDATE OF [db_changed] ON [DBchanges]  
		WHEN NEW.change_id = 1 AND NEW.db_changed <> 0  
			BEGIN  
 				SELECT DCSignalBB(0);  
 				UPDATE DBChanges SET db_changed=0 WHERE change_id=1;  
 			END;
