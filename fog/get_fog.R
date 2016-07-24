
# Create a table to store the data ----
library(RPostgreSQL)
pg <- dbConnect(PostgreSQL())

if (!dbExistsTable(pg, c("bgt", "fog"))) {
    rs <- dbGetQuery(pg, "
        CREATE TABLE bgt.fog
            (file_name text, category text,
             fog float8, num_words integer, percent_complex float8,
             num_sentences integer, fog_original float8,
             num_sentences_original integer)")

    rs <- dbGetQuery(pg, "CREATE INDEX ON bgt.fog (file_name, category)")
}
rs <- dbDisconnect(pg)

# Make a function to get fog data ----
get_fog_data <- function(file_name) {
    # Function to get statistics for within-call regressions
    # of fog of answers on fog of questions.

    library(RPostgreSQL)
    pg <- dbConnect(PostgreSQL())

    # Get fog data
    reg_data <- dbGetQuery(pg, paste0("
        INSERT INTO bgt.fog
        WITH raw_data AS (
            SELECT file_name, 
                (CASE WHEN role='Analyst' THEN 'anal' ELSE 'comp' END) || '_' || context
                    AS category, speaker_text
            FROM streetevents.speaker_data
            WHERE file_name='", file_name, "' AND speaker_name != 'Operator'),

        call_text AS (
            SELECT file_name, category, string_agg(speaker_text, ' ') AS all_text
            FROM raw_data
            GROUP BY file_name, category)

        SELECT file_name, category, (fog_data(all_text)).*
        FROM call_text"))

    dbDisconnect(pg)
}

# Get list of files without fog data ----
library(dplyr)
pg <- src_postgres()

calls <- tbl(pg, sql("SELECT *  FROM streetevents.calls"))

processed <- tbl(pg, sql("SELECT * FROM bgt.fog"))

file_names <-
    calls %>%
    filter(call_type==1L) %>%
    anti_join(processed) %>%
    select(file_name) %>%
    distinct() %>%
    as.data.frame(n=-1)

# Apply function to get fog data ----
# Run on 12 cores.
pg <- dbConnect(PostgreSQL())
library(parallel)
system.time(temp <- mclapply(file_names$file_name,
                             get_fog_data, mc.cores=8))

rs <- dbDisconnect(pg)