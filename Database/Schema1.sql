BEGIN TRANSACTION;

DROP TABLE IF EXISTS genre;
DROP TABLE IF EXISTS pianist;

CREATE TABLE genre
(
	genre_id INTEGER PRIMARY KEY,
	genre_name VARCHAR(64) NOT NULL COLLATE NOCASE
);

CREATE TABLE pianist
(
	pianist_id INTEGER PRIMARY KEY,
	pianist_name VARCHAR(64) NOT NULL COLLATE NOCASE,
	genre_id INTEGER NOT NULL,
	FOREIGN KEY (genre_id) REFERENCES genre(genre_id)
);

INSERT INTO genre VALUES (NULL, 'Classical');
INSERT INTO genre VALUES (NULL, 'Rag Time');
INSERT INTO genre VALUES (NULL, 'Jazz');
INSERT INTO genre VALUES (NULL, 'Rock ''n Roll');
INSERT INTO genre VALUES (NULL, 'Pop');

INSERT INTO pianist VALUES (NULL, 'Scott Joplin', 2);
INSERT INTO pianist VALUES (NULL, 'Dave Brubeck', 3);
INSERT INTO pianist VALUES (NULL, 'Jerry Lee Lewis', 4);

COMMIT;
