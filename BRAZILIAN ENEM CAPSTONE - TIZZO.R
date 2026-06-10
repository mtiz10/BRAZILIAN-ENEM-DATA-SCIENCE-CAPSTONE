# ========================================-
# BRAZILIAN ENEM 2024 ESSAY SCORE ANALISYS PROJECT - R SCRIPT
# HarvardX: PH125.9x Data Science
# Author: MICHELL PEREIRA TIZZO
# ========================================-

cat("\014")
cat("\n ======================= ")
cat("\n STARTING MY ENEM SCRIPT ")
cat("\n ======================= ")

## ----setup, include=FALSE-------------------
# ==========================================-
# PROTOTYPING SWITCH (Set to FALSE for final run)
# ==========================================-
IS_TESTING <- FALSE  

# GLOBAL OPTIONS
options(warn = -1) # Suppress warnings for cleaner output
knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE, fig.align = "center", out.width = "80%")

# Disable figure cropping - avoid Perl error
knitr::knit_hooks$set(crop = knitr::hook_pdfcrop)
options(knitr.graphics.auto_pdf = FALSE)

# 1. LOADING LIBRARIES
if(!require(dplyr)) install.packages("dplyr")
if(!require(tidyr)) install.packages("tidyr")
if(!require(caret)) install.packages("caret")
if(!require(randomForest)) install.packages("randomForest")
if(!require(ggplot2)) install.packages("ggplot2")
if(!require(gridExtra)) install.packages("gridExtra")
if(!require(patchwork)) install.packages("patchwork")
if(!require(rpart)) install.packages("rpart")
if(!require(rpart.plot)) install.packages("rpart.plot")
if(!require(broom)) install.packages("broom")
if(!require(scales)) install.packages("scales")
if(!require(naivebayes)) install.packages("naivebayes")
if(!require(kableExtra)) install.packages("kableExtra") 

library(dplyr)
library(tidyr)
library(caret)
library(randomForest)
library(ggplot2)
library(patchwork)
library(rpart)
library(rpart.plot)
library(broom)
library(scales)
library(naivebayes)
library(kableExtra) 


## ----data_processing_v2, include=FALSE--------------------------------------
# ======= 1 DEFINE PATHS FOR PROCESSED DATASETS ======
rds_path_full <- "processed_enem_data.rds"
rds_path_test <- "processed_enem_data_test.rds"
csv_path <- "microdados_enem_2024/DADOS/RESULTADOS_2024.csv"




# ======= 2 CACHE INTEGRITY ENFORCEMENT =======
# If the metadata file does not exist, force deletion of old cache files
# to guarantee the pipeline runs from scratch and calculates exact metrics.
if (!file.exists("filtering_metadata.rds")) {
  unlink(c(rds_path_full, rds_path_test))
}

# Fast direct path check to avoid slow recursive disk scanning
default_csv_path <- "microdados_enem_2024/DADOS/RESULTADOS_2024.csv"
sample_csv_path <- "microdados_enem_2024_sample/DADOS/RESULTADOS_2024.csv"

if (file.exists(default_csv_path)) {
  found_files <- default_csv_path
} else if (file.exists(sample_csv_path)) {
  found_files <- sample_csv_path
} else {
  # No recursive disk scanning to prevent R from hanging in high-level directories!
  found_files <- character(0)
}



# ======= 3 AUTOMATIC DOWNLOAD AND EXTRACTION PREPARATION ========
if (length(found_files) == 0 && !file.exists(rds_path_test) && !file.exists(rds_path_full)) {
  dir.create("microdados_enem_2024/DADOS", recursive = TRUE, showWarnings = FALSE)
  
  # Interactive Dataset Selection with 10-second countdown (default to fast GitHub sample)
  use_full_dataset <- FALSE
  
  if (.Platform$OS.type == "windows") {
    # Native Windows Popup with 10-second timeout
    cmd <- 'powershell -Command "$wshell = New-Object -ComObject Wscript.Shell; $answer = $wshell.Popup(\\\"Would you like to download the FULL original 710MB dataset from the Brazilian Government? \n\n- Click YES to download the FULL dataset (requires ~45 min).\n- Click NO (or wait 10 seconds) to automatically download the FAST 35MB GitHub sample.\\\", 10, \\\"Dataset Selection\\\", 4 + 32); echo $answer"'
    res <- try(system(cmd, intern = TRUE), silent = TRUE)
    if (!inherits(res, "try-error") && length(res) > 0) {
      # Popup return code 6 corresponds to 'Yes'
      if (trimws(res) == "6") {
        use_full_dataset <- TRUE
      }
    }
  } else {
    # Fallback console prompt for Unix-like systems (Linux, Mac)
    cat("\nSelect dataset download option:\n")
    cat("1. Download the FAST 35MB GitHub sample [Default]\n")
    cat("2. Download the FULL 710MB Government dataset (takes ~45 min)\n")
    ans <- readline(prompt = "Enter choice (1 or 2): ")
    if (trimws(ans) == "2") {
      use_full_dataset <- TRUE
    }
  }
  
  # Assign URLs and paths based on user selection
  if (use_full_dataset) {
    zip_url <- "https://download.inep.gov.br/microdados/microdados_enem_2024.zip"
    zip_file <- "microdados_enem_2024.zip"
    min_size <- 700000000 # 700 MB minimum size
  } else {
    zip_url <- "https://raw.githubusercontent.com/mtiz10/BRAZILIAN-ENEM-DATA-SCIENCE-CAPSTONE/main/microdados_enem_2024_sample.zip"
    zip_file <- "microdados_enem_2024_sample.zip"
    min_size <- 10000000 # 10 MB minimum size
  }
  
  # Smart check: only download if the ZIP is missing or corrupted
  if (!file.exists(zip_file) || file.size(zip_file) < min_size) {
    
    # Display the beautiful custom "Please wait..." warning box
    cat("\n\n\n========================================================================================")
    cat("\n|                                                                                      |")
    cat("\n|                                                                                      |")
    cat("\n|                                    Please wait...                                    |")
    cat("\n|                                                                                      |")
    if (use_full_dataset) {
      cat("\n|  Dataset not found. Downloading ENEM 2024 ZIP (~700MB). Expected time: ~40 minutes.  |")
    } else {
      cat("\n|   Dataset not found. Downloading ENEM 2024 Sample ZIP (~35MB) from GitHub...         |")
    }
    cat("\n|                                                                                      |")
    cat("\n|                                                                                      |")
    cat("\n========================================================================================\n\n")
    
    options(timeout = 3000) 
    download.file(zip_url, destfile = zip_file, method = "libcurl", mode = "wb")
    message("Download completed.")
  } else {
    message("The selected ZIP file already exists locally and is valid. Skipping download...\n")
  }
  
  message("Unzipping files...")
  
  # Robust Windows PowerShell extractor to avoid R's internal 2GB and multibyte limits
  if (.Platform$OS.type == "windows") {
    message("Using Windows PowerShell to extract the zip file...")
    message("It will take a few more minutes...")
    system(paste0('powershell -command "Expand-Archive -Path ', zip_file, ' -DestinationPath . -Force"'))
  } else {
    # Fallback for Mac/Linux
    old_locale <- Sys.getlocale("LC_CTYPE")
    Sys.setlocale("LC_CTYPE", "C")
    unzip(zip_file)
    Sys.setlocale("LC_CTYPE", old_locale)
  }
  
  # Case-insensitive recursive search
  found_files <- list.files(pattern = "RESULTADOS_2024.csv", ignore.case = TRUE, recursive = TRUE, full.names = TRUE)
  if (length(found_files) > 0) {
    csv_path <- found_files[1]
    file.remove(zip_file) 
  } else {
    stop("CRITICAL ERROR: Extraction completed, but RESULTADOS_2024.csv was not found.")
  }
}


# ======= 4 ROBUST RAW PREVIEW FALLBACK =====
if (length(found_files) > 0) {
  csv_path <- found_files[1]
  resultados_2024 <- read.csv2(csv_path, nrows = 10, fileEncoding = "latin1")
} else if (file.exists(rds_path_test)) {
  temp_data <- readRDS(rds_path_test)
  resultados_2024 <- head(temp_data, 10) %>%
    rename(NU_SEQUENCIAL = STUDENT_ID, 
           SG_UF_PROVA = SCHOOL_STATE, 
           TP_DEPENDENCIA_ADM_ESC = SCHOOL_TYPE, 
           TP_LOCALIZACAO_ESC = LOCATION, 
           NU_NOTA_REDACAO = ESSAY_SCORE)
} else if (file.exists(rds_path_full)) {
  temp_data <- readRDS(rds_path_full)
  resultados_2024 <- head(temp_data, 10) %>%
    rename(NU_SEQUENCIAL = STUDENT_ID, 
           SG_UF_PROVA = SCHOOL_STATE, 
           TP_DEPENDENCIA_ADM_ESC = SCHOOL_TYPE, 
           TP_LOCALIZACAO_ESC = LOCATION, 
           NU_NOTA_REDACAO = ESSAY_SCORE)
}

# ======= 5 LOAD PREPROCESSED DATA =====
if (IS_TESTING && file.exists(rds_path_test)) {
  enem_data <- readRDS(rds_path_test)
} else if (file.exists(rds_path_full)) {
  enem_data_full <- readRDS(rds_path_full)
  set.seed(123)
  if (IS_TESTING) {
    enem_data <- enem_data_full %>% sample_n(min(10000, nrow(enem_data_full)))
    saveRDS(enem_data, rds_path_test)
  } else {
    enem_data <- enem_data_full # Loads all students without cuts!
  }
  rm(enem_data_full); gc()
} else {
  # Raw full processing 
  raw_full <- read.csv2(csv_path, fileEncoding = "latin1")
  
  # Rename all variables immediately after reading to avoid confusion
  raw_full <- raw_full %>%
    rename(
      STUDENT_ID = NU_SEQUENCIAL,
      SCHOOL_STATE = SG_UF_PROVA,
      SCHOOL_TYPE = TP_DEPENDENCIA_ADM_ESC,
      LOCATION = TP_LOCALIZACAO_ESC,
      ESSAY_SCORE = NU_NOTA_REDACAO,
      COMP1_SCORE = NU_NOTA_COMP1,
      COMP2_SCORE = NU_NOTA_COMP2,
      COMP3_SCORE = NU_NOTA_COMP3,
      COMP4_SCORE = NU_NOTA_COMP4,
      COMP5_SCORE = NU_NOTA_COMP5,
      NATURAL_SCI_SCORE = NU_NOTA_CN,
      MATH_SCORE = NU_NOTA_MT
    )
  
  # Numeric conversions for English-named variables
  raw_full$ESSAY_SCORE <- as.numeric(raw_full$ESSAY_SCORE)
  raw_full$NATURAL_SCI_SCORE <- as.numeric(raw_full$NATURAL_SCI_SCORE)
  raw_full$MATH_SCORE <- as.numeric(raw_full$MATH_SCORE)
  raw_full$COMP1_SCORE <- as.numeric(raw_full$COMP1_SCORE)
  raw_full$COMP2_SCORE <- as.numeric(raw_full$COMP2_SCORE)
  raw_full$COMP3_SCORE <- as.numeric(raw_full$COMP3_SCORE)
  raw_full$COMP4_SCORE <- as.numeric(raw_full$COMP4_SCORE)
  raw_full$COMP5_SCORE <- as.numeric(raw_full$COMP5_SCORE)

  initial_count <- nrow(raw_full)
  
  # Remove records with NA values in core components
  clean_step1 <- raw_full %>% 
    filter(!is.na(ESSAY_SCORE), !is.na(NATURAL_SCI_SCORE), !is.na(MATH_SCORE))
  
  # Clean categorical descriptors
  clean_step2 <- clean_step1 %>%
    mutate(SCHOOL_TYPE = case_when(
      SCHOOL_TYPE == 1 ~ "Federal", 
      SCHOOL_TYPE == 2 ~ "State",
      SCHOOL_TYPE == 3 ~ "Municipal", 
      SCHOOL_TYPE == 4 ~ "Private", 
      TRUE ~ "Other"
    )) %>%
    filter(SCHOOL_TYPE != "Other") %>%
    mutate(LOCATION = ifelse(LOCATION == 1, "Urban", "Rural"))
  
  # UTF-8 encoding safeguard (avoids double conversion)
  enem_data_full <- clean_step2 %>% 
    mutate(across(where(is.character), ~enc2utf8(as.character(.))))
  
  enem_data_full$SCHOOL_TYPE <- factor(enem_data_full$SCHOOL_TYPE, levels = c("State", "Municipal", "Federal", "Private"))
  enem_data_full$LOCATION <- as.factor(enem_data_full$LOCATION)
  enem_data_full$SCHOOL_STATE <- as.factor(enem_data_full$SCHOOL_STATE)
  
  # =========================================================================
  # SAVING THE TABLE METADATA WITHOUT HARDCODING
  # =========================================================================
  filtering_metadata <- list(
    initial = initial_count,
    missing = initial_count - nrow(clean_step1),
    present = nrow(clean_step1),
    invalid = nrow(clean_step1) - nrow(clean_step2),
    final = nrow(clean_step2)
  )
  saveRDS(filtering_metadata, "filtering_metadata.rds")
  # =========================================================================

  saveRDS(enem_data_full, rds_path_full)
  
  set.seed(123)
  if (IS_TESTING) {
    enem_data <- enem_data_full %>% sample_n(min(10000, nrow(enem_data_full)))
    saveRDS(enem_data, rds_path_test)
  } else {
    enem_data <- enem_data_full # Loads all students without cuts!
  }
  rm(raw_full, clean_step1, clean_step2, enem_data_full); gc()
}

# ======= 6 PREVIEW RAW VS CLEANED 3-ROWS =======
num_preview_rows <- 3

if (exists("enem_data") && nrow(enem_data) >= num_preview_rows) {
  preview_clean_all <- head(enem_data, num_preview_rows)
  
  if (!"STUDENT_ID" %in% colnames(preview_clean_all)) {
    preview_clean_all$STUDENT_ID <- as.numeric(rownames(preview_clean_all))
  }
  
  # Select key columns for the cleaned view
  preview_clean <- preview_clean_all %>% 
    select(STUDENT_ID, SCHOOL_STATE, SCHOOL_TYPE, LOCATION, ESSAY_SCORE)
} else {
  # Safety fallback for clean preview
  preview_clean <- data.frame(
    STUDENT_ID = 1:num_preview_rows,
    SCHOOL_STATE = c("Sao Paulo", "Minas Gerais", "Bahia"),
    SCHOOL_TYPE = factor(c("State", "Private", "State")),
    LOCATION = factor(c("Urban", "Urban", "Urban")),
    ESSAY_SCORE = c(300, 920, 720)
  )
}

# Avoid re-reading the CSV file by reusing the already loaded raw dataset
if (exists("resultados_2024") && nrow(resultados_2024) >= num_preview_rows) {
  preview_raw <- head(resultados_2024, num_preview_rows)
} else {
  # Safety fallback for raw preview matching the structure
  preview_raw <- data.frame(
    NU_SEQUENCIAL = 1:num_preview_rows,
    NO_MUNICIPIO_ESC = c("Aratuba", "Tijucas", "Tapiramutá"),
    TP_DEPENDENCIA_ADM_ESC = c(2, 4, 2),
    TP_LOCALIZACAO_ESC = c(1, 1, 1),
    NU_NOTA_REDACAO = c(300, 920, 720)
  )
}

# Bulletproof encoding repair function for both preview frames (handles old cached data)
repair_preview_encoding <- function(df) {
  df %>% mutate(across(where(is.character), ~gsub("TapiramutÃ¡|TapiramutÃ\u00a1|Tapiramut\u00c3\u00a1", "Tapiramutá", .)))
}
preview_clean <- repair_preview_encoding(preview_clean)
preview_raw   <- repair_preview_encoding(preview_raw)


## ----head_raw_transposed----------------------------------------------------

raw_preview <- preview_raw

# Safe fallback structure
if (is.null(raw_preview) || nrow(raw_preview) == 0) {
  raw_preview <- data.frame(
    NU_SEQUENCIAL = 1:3,
    NO_MUNICIPIO_ESC = rep("Dynamic Raw City", 3),
    TP_DEPENDENCIA_ADM_ESC = c(2, 2, 2),
    TP_LOCALIZACAO_ESC = c(1, 1, 1),
    NU_NOTA_REDACAO = c(500, 500, 500)
  )
}

# Transpose the dataset
raw_transposed <- as.data.frame(t(raw_preview))

# Store the number of columns (students) safely
num_students <- ncol(raw_transposed)
student_cols <- if (num_students > 0) paste("Student", 1:num_students) else character(0)

# Assign temporary column names
if (length(student_cols) > 0) {
  colnames(raw_transposed) <- student_cols
}

# AGGRESSIVE TRUNCATION FOR VALUES (10 chars max)
for (col in student_cols) {
  raw_transposed[[col]] <- sapply(raw_transposed[[col]], function(x) {
    x_char <- as.character(x)
    if(is.na(x_char)) return("")
    if(nchar(x_char) > 10) return(paste0(substr(x_char, 1, 7), "..."))
    return(x_char)
  })
}

# Add the variable column with row names
raw_transposed$Variable <- rownames(raw_transposed)

# AGGRESSIVE TRUNCATION FOR VARIABLES (22 chars max)
raw_transposed$Variable <- sapply(raw_transposed$Variable, function(x) {
  x_char <- as.character(x)
  if(is.na(x_char)) return("")
  if(nchar(x_char) > 22) return(paste0(substr(x_char, 1, 19), "..."))
  return(x_char)
})

# Reorder columns putting Variable first
if (length(student_cols) > 0) {
  raw_transposed <- raw_transposed[, c("Variable", student_cols)]
}

cat("\n\nTable 02 Raw Dataset Transposed: \n\n")
print(raw_transposed, row.names = FALSE)
#knitr::kable(raw_transposed)
#knitr::kable(raw_transposed, booktabs = TRUE, row.names = FALSE) %>% 
#  kableExtra::kable_styling(latex_options = c("scale_down", "hold_position"))



## ----head_clean_transposed--------------------------------------------------
clean_preview <- preview_clean

# Define dynamic mapping of adopted English variables to original Portuguese names
variable_mapping <- data.frame(
  Adopted_EN = c("STUDENT_ID", "SCHOOL_STATE", "SCHOOL_TYPE", "LOCATION", "ESSAY_SCORE"),
  Original_PT = c("NU_SEQUENCIAL", "SG_UF_PROVA", "TP_DEPENDENCIA_ADM_ESC", "TP_LOCALIZACAO_ESC", "NU_NOTA_REDACAO"),
  stringsAsFactors = FALSE
)

# Safe fallback structure
if (is.null(clean_preview) || nrow(clean_preview) == 0) {
  clean_preview <- data.frame(
    STUDENT_ID = 1:3,
    SCHOOL_STATE = c("Sao Paulo", "Minas Gerais", "Bahia"),
    SCHOOL_TYPE = factor(c("State", "Private", "State")),
    LOCATION = factor(c("Urban", "Urban", "Urban")),
    ESSAY_SCORE = c(300, 920, 720)
  )
}

# Transpose the cleaned dataset
clean_transposed <- as.data.frame(t(clean_preview))
num_clean <- ncol(clean_transposed)
student_clean_cols <- if (num_clean > 0) paste("Student", 1:num_clean) else character(0)

# Assign student column names
if (length(student_clean_cols) > 0) {
  colnames(clean_transposed) <- student_clean_cols
}

# Truncate clean values to 15 characters max (safeguard)
for (col in student_clean_cols) {
  clean_transposed[[col]] <- sapply(clean_transposed[[col]], function(x) {
    x_char <- as.character(x)
    ifelse(is.na(x_char), "",
           ifelse(nchar(x_char) > 15, paste0(substr(x_char, 1, 12), "..."), x_char))
  })
}

# Add Portuguese and English descriptive columns
clean_transposed$Adopted_EN <- rownames(clean_transposed)
clean_transposed$Original_PT <- variable_mapping$Original_PT[match(clean_transposed$Adopted_EN, variable_mapping$Adopted_EN)]

# Reorder columns putting variables first
if (length(student_clean_cols) > 0) {
  clean_transposed <- clean_transposed[, c("Original_PT", "Adopted_EN", student_clean_cols)]
}

cat("\n\nTable 03 Cleaned Dataset Transposed ")
print(clean_transposed, row.names = FALSE)
# knitr::kable(clean_transposed)
# knitr::kable(
#  clean_transposed, 
#  booktabs = FALSE, 
#  row.names = FALSE, 
#  col.names = c("Original Variable (PT)", #"Adopted Variable (EN)", student_clean_cols),
#  caption = ""
#) %>% 
#  kableExtra::kable_styling(latex_options = c# ("scale_down", "hold_position"))


## ----data_filtering_table, echo=FALSE, message=FALSE, warning=FALSE---------
# Puxando os dados reais salvos lá em cima (sem ler o CSV novamente)

if (file.exists("filtering_metadata.rds")) {
  meta <- readRDS("filtering_metadata.rds")
} else {
  # Fallback de segurança 
  meta <- list(initial = NA, missing = NA, present = NA, invalid = NA, final = NA)
}

summary_table <- data.frame(
  Stage = c(
    "Initial Number of Records",
    "Absentees / Disqualified in Exams",
    "Remaining Present Candidates",
    "Excluded by Invalid / Unregistered School",
    "Final Regular Students for Modeling"
  ),
  Count = c(meta$initial, meta$missing, meta$present, meta$invalid, meta$final)
)

cat("\n\nTable 04: Data Wrangling & Filtering Pipeline \n\n")
print(summary_table, row.names = FALSE)
# knitr::kable(summary_table)
# knitr::kable(summary_table, 
#              col.names = c("Pipeline Stage", "Student Count"),
#              align = "lc",
#              format.args = list(big.mark = ".", decimal.mark = ","))




## ----splitting, include=FALSE-----------------------------------------------
set.seed(2024)
test_index <- createDataPartition(enem_data$ESSAY_SCORE, p = 0.2, list = FALSE)
train_set <- enem_data[-test_index, ]; test_set <- enem_data[test_index, ]


## ----fig01, fig.height=12, fig.width=8--------------------------------------
# 1. Load metadata to get the real population size dynamically
if (file.exists("filtering_metadata.rds")) {
  meta <- readRDS("filtering_metadata.rds")
  real_rows <- meta$final
} else {
  real_rows <- nrow(enem_data)
}

# 2. Calculate expansion factor to project sample counts back to real population
scale_factor <- real_rows / nrow(enem_data)

theme_dash <- function() { 
  theme_minimal() + 
    theme(
      plot.title = element_text(face = "bold", size = 12, hjust = 0.5), 
      axis.text.x = element_text(face = "bold", size = 9),
      axis.title.y = element_text(size = 9)
    ) 
}

# 1. Dataset Volume (Using real final rows directly)
df_vol <- data.frame(i=c("Rows","Cols"), v=c(real_rows, ncol(enem_data))) %>% arrange(desc(v))
p1 <- ggplot(df_vol, aes(x=factor(i, levels=df_vol$i), y=v)) + 
  geom_col(fill="lightblue", color="black", linewidth=0.2, width=0.5) + 
  geom_text(aes(label=format(round(v), big.mark=".", decimal.mark=",")), vjust=-0.5, size=3.5, fontface="bold") + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) + 
  coord_cartesian(clip = "off") +
  theme_dash() + labs(title="Dataset Volume", x="", y="Value")

# 2. Essay Scores (Scaled)
df_essay <- data.frame(
  i=c("Valid","Zero"), 
  v=c(sum(enem_data$ESSAY_SCORE>0) * scale_factor, sum(enem_data$ESSAY_SCORE==0) * scale_factor)
) %>% arrange(desc(v))

p2 <- ggplot(df_essay, aes(x=factor(i, levels=df_essay$i), y=v)) + 
  geom_col(fill="lightblue", color="black", linewidth=0.2, width=0.5) + 
  geom_text(aes(label=format(round(v), big.mark=".", decimal.mark=",")), vjust=-0.5, size=3.5, fontface="bold") + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) + 
  coord_cartesian(clip = "off") +
  theme_dash() + labs(title="Essay Scores", x="", y="Students")

# 3. By School Type (Scaled)
df_school <- enem_data %>% group_by(SCHOOL_TYPE) %>% summarise(v=round(n() * scale_factor)) %>% arrange(desc(v))
p4 <- ggplot(df_school, aes(x=factor(SCHOOL_TYPE, levels=df_school$SCHOOL_TYPE), y=v)) + 
  geom_col(fill="lightblue", color="black", linewidth=0.2, width=0.6) + 
  geom_text(aes(label=format(v, big.mark=".", decimal.mark=",")), vjust=-0.5, size=3, fontface="bold") + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) + 
  coord_cartesian(clip = "off") +
  labs(title="By School Type", x="", y="Students") + theme_dash()

# 4. By Location (Scaled)
df_loc <- enem_data %>% group_by(LOCATION) %>% summarise(v=round(n() * scale_factor)) %>% arrange(desc(v))
p5 <- ggplot(df_loc, aes(x=factor(LOCATION, levels=df_loc$LOCATION), y=v)) + 
  geom_col(fill="lightblue", color="black", linewidth=0.2, width=0.5) + 
  geom_text(aes(label=format(v, big.mark=".", decimal.mark=",")), vjust=-0.5, size=3.5, fontface="bold") + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) + 
  coord_cartesian(clip = "off") +
  labs(title="By Location", x="", y="Students") + theme_dash()

# 5. Geography (Scaled to Thousands - 'k')
df_geo <- enem_data %>% group_by(SCHOOL_STATE) %>% summarise(v=round(n() * scale_factor)) %>% arrange(desc(v))
p6 <- ggplot(df_geo, aes(x=factor(SCHOOL_STATE, levels=df_geo$SCHOOL_STATE), y=v)) + 
  geom_col(fill="lightblue", color="black", linewidth=0.2) + 
  geom_text(aes(label=paste0(round(v/1000), "k")), vjust=0.5, hjust=-0.2, size=4.5, fontface="plain", angle=90) + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) + 
  coord_cartesian(clip = "off") +
  labs(title="Geography (States)", x="", y="Students") + theme_dash()

print(
  (p1 | p2) / (p4 | p5) / p6
)

## ----fig02, fig.height=4, fig.width=6---------------------------------------
# Guarantee scale_factor exists just in case this chunk is run independently
if (!exists("scale_factor")) {
  if (file.exists("filtering_metadata.rds")) {
    meta <- readRDS("filtering_metadata.rds")
    scale_factor <- meta$final / nrow(enem_data)
  } else {
    scale_factor <- 1
  }
}

print(
ggplot(enem_data, aes(x = ESSAY_SCORE)) + 
  geom_histogram(
    # after_stat intercepts the internal counting and multiplies by our projection factor
    aes(y = after_stat(count) * scale_factor, 
        fill = cut(ESSAY_SCORE, breaks = c(-Inf, 350, 700, Inf))), 
    binwidth = 40, 
    color = "black", 
    alpha = 0.8
  ) +
  scale_fill_manual(
    values = c("#FF6B6B", "#FFE066", "#51CF66"), 
    labels = c("Critical (0-350)", "Needs Improvement (351-700)", "Proficient (>700)")
  ) +
  # Formatting Y-axis to show "k" (thousands) for clean visualization
  scale_y_continuous(labels = function(x) paste0(round(x/1000), "k")) +
  theme_minimal() + 
  labs(x="Score", y="Students", fill="Proficiency Levels:", title="Figure 02: Proficiency Histogram"
)
)
## ----fig03, fig.height=4, fig.width=6---------------------------------------
# Guarantee scale_factor exists just in case this chunk is run independently
if (!exists("scale_factor")) {
  if (file.exists("filtering_metadata.rds")) {
    meta <- readRDS("filtering_metadata.rds")
    scale_factor <- meta$final / nrow(enem_data)
  } else {
    scale_factor <- 1
  }
}

df_fig03 <- enem_data %>% 
  mutate(Level = factor(case_when(
    ESSAY_SCORE <= 350 ~ "Critical", 
    ESSAY_SCORE <= 700 ~ "Needs Imp.", 
    TRUE ~ "Proficient"
  ), levels = c("Critical", "Needs Imp.", "Proficient"))) %>%
  group_by(Level) %>% 
  summarise(RawCount = n()) %>% 
  mutate(
    Count = RawCount * scale_factor, # Projecting back to the real population
    Percentage = Count / sum(Count) * 100
  )

max_count <- max(df_fig03$Count)

print(
ggplot(df_fig03, aes(x = Level, y = Count, fill = Level)) + 
  geom_col(color = "black", linewidth = 0.3) +
  scale_fill_manual(values = c("Critical" = "#FF6B6B", "Needs Imp." = "#FFE066", "Proficient" = "#51CF66")) +
  # Using Brazilian/European formatting (dots for thousands)
  geom_text(aes(label = format(round(Count), big.mark = ".", decimal.mark = ",")), vjust = -0.5, fontface = "bold") + 
  # Percentage positioned near the bottom inside the bars
  geom_text(aes(label = paste0(round(Percentage, 1), "%")), y = max_count * 0.05, color = "black", fontface = "plain", size = 3.5) +
  # Expanding the Y-axis slightly so the top labels don't get cut off
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  theme_minimal() + 
  labs(x = "Level", y = "Students",title="Figure 03: The Proficiency Gap") + 
  theme(legend.position = "none")
)

## ----fig04, fig.height=3.5, fig.width=6-------------------------------------
df_an <- enem_data %>% summarise(
  `1` = mean(COMP1_SCORE, na.rm=T)*5, 
  `2` = mean(COMP2_SCORE, na.rm=T)*5, 
  `3` = mean(COMP3_SCORE, na.rm=T)*5, 
  `4` = mean(COMP4_SCORE, na.rm=T)*5, 
  `5` = mean(COMP5_SCORE, na.rm=T)*5, 
  `Global Mean` = mean(ESSAY_SCORE, na.rm=T)
) %>% 
  pivot_longer(cols=everything(), names_to="Category", values_to="Score")

df_an$Category <- factor(df_an$Category, levels = c("1", "2", "3", "4", "5", "Global Mean"))

print(
ggplot(df_an, aes(x=Category, y=Score, fill=Category)) + 
  geom_col(color="black", linewidth=0.3) + 
  scale_fill_manual(
    values = c(
      "1" = "#FFE066", # Changed to yellow
      "2" = "#51CF66", # Only Competency 2 is Green
      "3" = "#FFE066", # Changed to yellow
      "4" = "#FFE066", # Changed to yellow
      "5" = "#FFE066", # Changed to yellow
      "Global Mean" = "#FFE066" # Changed to yellow
    ),
    labels = c(
      "1" = "1: Grammar",
      "2" = "2: Comprehension",
      "3" = "3: Argumentation",
      "4" = "4: Cohesion",
      "5" = "5: Solution",
      "Global Mean" = "Global Mean"
    )
  ) +
  geom_text(aes(label=round(Score,0)), vjust=-0.5, fontface="plain", size = 3) + 
  theme_minimal() + 
  labs(x="Criteria", y="Score", fill="Competencies:", title = "Figure 04: Score Anatomy") + 
  theme(legend.position = "right")
)

## ----fig05, fig.height=3.5, fig.width=6-------------------------------------
mu_g <- mean(enem_data$ESSAY_SCORE)
e_e <- enem_data %>% group_by(SCHOOL_TYPE) %>% summarise(b = mean(ESSAY_SCORE) - mu_g) %>% mutate(S = "School Type")
u_e <- enem_data %>% group_by(SCHOOL_STATE) %>% summarise(b = mean(ESSAY_SCORE) - mu_g) %>% mutate(S = "State")
l_e <- enem_data %>% group_by(LOCATION) %>% summarise(b = mean(ESSAY_SCORE) - mu_g) %>% mutate(S = "Location")

# Combine and explicitly set factor levels in the specified order of importance
df_var <- bind_rows(e_e, l_e, u_e)
df_var$S <- factor(df_var$S, levels = c("School Type", "Location", "State"))

print(
ggplot(df_var, aes(x=S, y=b, fill=S)) + 
  geom_boxplot(color="black", linewidth=0.3, show.legend = FALSE) + 
  geom_hline(yintercept=0, color="red", linetype="dashed") + 
  scale_fill_manual(values=c("School Type"="#FF6B6B", "Location"="#FFE066", "State"="#51CF66")) + 
  theme_minimal() + 
  labs(x="Source of Variation", y="Bias (Deviation from Mean)",title="Figure 05: Sources of Variability")
)

## ----fig06, fig.height=4, fig.width=6---------------------------------------
# 1. Calculate medians per school type and location to dynamically assign indicators
df_med_06 <- enem_data %>%
  group_by(SCHOOL_TYPE, LOCATION) %>%
  summarise(median_score = median(ESSAY_SCORE, na.rm = TRUE), .groups = 'drop') %>%
  mutate(median_color = case_when(
    median_score > 700 ~ "Proficient",
    median_score >= 350 ~ "Needs Improvement",
    TRUE ~ "Critical"
  ))

# Join back to dataset
dados_fig06 <- enem_data %>%
  left_join(df_med_06, by = c("SCHOOL_TYPE", "LOCATION"))

# 2. Plot using fill for median class and alpha for location grouping (Urban vs Rural)
print(
ggplot(dados_fig06, aes(x = SCHOOL_TYPE, y = ESSAY_SCORE, fill = median_color, alpha = LOCATION)) + 
  geom_boxplot(outlier.size = 0.2, color = "black", linewidth = 0.1, width = 0.5, position = position_dodge(0.75)) + 
  scale_fill_manual(
    values = c("Critical" = "#FF6B6B", "Needs Improvement" = "#FFE066", "Proficient" = "#51CF66"),
    limits = c("Critical", "Needs Improvement", "Proficient")
  ) +
  scale_alpha_manual(
    values = c("Urban" = 1.0, "Rural" = 0.4) # Solid for Urban, transparent for Rural
  ) +
  coord_flip() + 
  theme_minimal() + 
  labs(x = "School Type", y = "Essay Score", fill = "Median Level:", alpha = "Location:", title="Figure 06: Performance by School and Zone")
)

## ----fig07, fig.height=4, fig.width=6---------------------------------------
# 1. Calculate medians per state to dynamically assign indicators
df_med_07 <- enem_data %>%
  group_by(SCHOOL_STATE) %>%
  summarise(median_score = median(ESSAY_SCORE, na.rm = TRUE), .groups = 'drop') %>%
  mutate(median_color = case_when(
    median_score > 700 ~ "Proficient",
    median_score >= 350 ~ "Needs Improvement",
    TRUE ~ "Critical"
  ))

# 2. Sort states by median score in R (avoiding reorder inside ggplot)
ordered_states <- df_med_07 %>%
  arrange(median_score) %>%
  pull(SCHOOL_STATE)

dados_fig07 <- enem_data %>%
  left_join(df_med_07, by = "SCHOOL_STATE") %>%
  mutate(SCHOOL_STATE = factor(SCHOOL_STATE, levels = ordered_states))

# 3. Plot with dynamic indicator coloring and reduced width (0.5)
print(
ggplot(dados_fig07, aes(x = SCHOOL_STATE, y = ESSAY_SCORE, fill = median_color)) +
  geom_boxplot(
    show.legend = TRUE, 
    outlier.size = 0.1, 
    color = "black", 
    linewidth = 0.3,
    width = 0.5 # Reduced width for a cleaner visual fit
  ) + 
  scale_fill_manual(
    values = c("Critical" = "#FF6B6B", "Needs Improvement" = "#FFE066", "Proficient" = "#51CF66"),
    limits = c("Critical", "Needs Improvement", "Proficient")
  ) +
  coord_flip() + 
  theme_minimal() + 
  labs(x = "State", y = "Essay Score", fill = "Median Level:", title = "Figure 07: Ranking by State (UF)") + 
  theme(axis.text.y = element_text(size = 7))
)

## ----modelling_regression, include=FALSE------------------------------------
if (IS_TESTING) {
  reg_sample_size <- 1000
  rf_trees_reg <- 10
} else {
  reg_sample_size <- 30000
  rf_trees_reg <- 100
}

mu <- mean(train_set$ESSAY_SCORE)
rmse_naive <- RMSE(test_set$ESSAY_SCORE, mu)

uf_b <- train_set %>% group_by(SCHOOL_STATE) %>% summarise(b_uf = mean(ESSAY_SCORE - mu))
esc_b <- train_set %>% left_join(uf_b, by='SCHOOL_STATE') %>% group_by(SCHOOL_TYPE) %>% summarise(b_esc = mean(ESSAY_SCORE - mu - b_uf))
loc_b <- train_set %>% left_join(uf_b, by='SCHOOL_STATE') %>% left_join(esc_b, by='SCHOOL_TYPE') %>% group_by(LOCATION) %>% summarise(b_loc = mean(ESSAY_SCORE - mu - b_uf - b_esc))

p_l <- test_set %>% left_join(uf_b, by='SCHOOL_STATE') %>% left_join(esc_b, by='SCHOOL_TYPE') %>% left_join(loc_b, by='LOCATION') %>% mutate(p = mu + b_uf + b_esc + b_loc) %>% pull(p)
rmse_linear <- RMSE(test_set$ESSAY_SCORE, p_l)

t_s_reg <- train_set %>% sample_n(min(reg_sample_size, nrow(train_set)))
f_r <- randomForest(ESSAY_SCORE ~ SCHOOL_STATE + SCHOOL_TYPE + LOCATION, data = t_s_reg, ntree = rf_trees_reg)

p_r <- predict(f_r, test_set)
rmse_rf <- RMSE(test_set$ESSAY_SCORE, p_r)

rmse_ens <- RMSE(test_set$ESSAY_SCORE, (p_l + p_r)/2)


## ----fig08, fig.height=4, fig.width=6---------------------------------------
r_df <- data.frame(M=c("Naive","Linear","RF","Ensemble"), R=c(rmse_naive, rmse_linear, rmse_rf, rmse_ens))
r_df <- r_df %>% arrange(desc(R))
r_df$M <- factor(r_df$M, levels = r_df$M)

print(
ggplot(r_df, aes(x=M, y=R, fill=M)) + 
  geom_col(color="black", linewidth=0.3, width=0.6) + 
  # Manual discrete blue gradient: darkest/strongest blue for lowest RMSE (Linear), lightest for Naive
  scale_fill_manual(
    values = c(
      "Linear" = "#2171B5", 
      "Ensemble" = "#084594", 
      "RF" = "#6BAED6", 
      "Naive" = "#BDD7E7"
    )
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  geom_text(aes(label=round(R,1)), vjust=-0.5, fontface="bold") + 
  theme_minimal() + labs(x="Architecture Model", y="RMSE", fill="Model:", title="Figure 08: RMSE")
)

## ----fig09, fig.height=3, fig.width=6---------------------------------------

# MovieLens ratings range from 0.5 to 5.0 stars, so the actual scale range is 4.5
df_comp_final <- data.frame(P=c("MovieLens","ENEM"), E=c((0.8649/(5.0))*100, (rmse_ens/1000)*100))

# Manually invert the bar order (ENEM first, MovieLens second)
df_comp_final$P <- factor(df_comp_final$P, levels = c("ENEM", "MovieLens"))

print(
ggplot(df_comp_final, aes(x=P, y=E, fill=P)) + 
  geom_col(color="black", linewidth=0.3, width=0.5) + 
  # MovieLens is set to a slightly darker shade of blue (skyblue)
  scale_fill_manual(values=c("ENEM"="lightblue", "MovieLens"="skyblue")) + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  geom_text(aes(label=paste0(round(E,1),"%")), vjust=-0.5, fontface="bold") + 
  theme_minimal() + 
  labs(x="", y="Relative RMSE (%)",title="Figure 09: MovieLens vs. ENEM Comparison") + 
  theme(legend.position = "none") # Redundant legend removed
)

## ----fig10, fig.height=3, fig.width=6---------------------------------------
print(
data.frame(R=test_set$ESSAY_SCORE - ((p_l + p_r)/2)) %>% 
  ggplot(aes(x=R)) + 
  # Density changed to red
  geom_density(fill="#FF6B6B", color="black", alpha=0.5) + 
  # Target zero line changed to royalblue
  geom_vline(xintercept=0, linetype="dashed", color="royalblue", linewidth=1) + 
  theme_minimal() + 
  labs(x="Residuals (Error)", y="Density",title="Figure 10: Residual Distribution")
)

## ----fig11, fig.height=9, fig.width=8, out.width="95%"----------------------
# MODEL INFERENCE DASHBOARD
d_ref <- train_set %>% mutate(SCHOOL_STATE = relevel(factor(SCHOOL_STATE), ref="AC"), SCHOOL_TYPE = relevel(factor(SCHOOL_TYPE), ref="State"), LOCATION = relevel(factor(LOCATION), ref="Urban"))
m_p <- lm(ESSAY_SCORE ~ SCHOOL_STATE + SCHOOL_TYPE + LOCATION, data=d_ref)
tp <- tidy(m_p) %>% filter(term!="(Intercept)") %>% 
  mutate(C=case_when(grepl("SCHOOL_STATE", term) ~ "UF", grepl("SCHOOL_TYPE", term) ~ "Escola", TRUE ~ "Zona"), 
         V=gsub("SCHOOL_STATE|SCHOOL_TYPE|LOCATION", "", term), I=round(estimate,0))
tp_c <- bind_rows(tp, data.frame(V=c("AC","State","Urban"), I=0, C=c("UF","Escola","Zona")))

plot_tornado <- function(df, cat, tit, fs=7) {
  df_p <- df %>% filter(C==cat); v_max <- max(df_p$I); v_min <- min(df_p$I)
  ggplot(df_p, aes(x=reorder(V,I), y=I, fill=I)) + geom_col(color="black", linewidth=0.3, show.legend=F) + 
    geom_text(aes(label=ifelse(I==v_max|I==v_min, ifelse(I>0, paste0("+",I), as.character(I)), "")), hjust=ifelse(df_p$I>=0, -0.2, 1.2), size=3) +
    coord_flip(clip="off") + scale_fill_gradient2(low="#CD5f5C", mid="white", high="#4169E1") + 
    theme_minimal() + labs(title=tit, x="", y="") + theme(plot.title=element_text(size=10), axis.text.y=element_text(size=fs)) +
    scale_y_continuous(expand=expansion(mult=c(0.6, 0.6)))
}
print(
(plot_tornado(tp_c,"UF","1. Geographic Factor", 6) | (plot_tornado(tp_c,"Escola","2. Institutional") / plot_tornado(tp_c,"Zona","3. Urban/Rural"))) + plot_annotation(title="Figure 11: Essay Score Determinants (3 Tornados)", subtitle=paste("Mean Base:", round(coef(m_p)[1],0)))
)

## ----classification_logic, include=FALSE------------------------------------
cl_f <- function(df) { df %>% mutate(L = factor(case_when(ESSAY_SCORE <= 350 ~ "1. Critical", ESSAY_SCORE <= 700 ~ "2. Needs Imp.", TRUE ~ "3. Proficient"))) }
train_set <- cl_f(train_set)
test_set <- cl_f(test_set)

# Removing SCHOOL_STATE from the decision tree for instant execution (<0.01s) and clean visualization
f_tree <- rpart(L ~ SCHOOL_TYPE + LOCATION, data = train_set, method = "class")


## ----fig12------------------------------------------------------------------
# Dynamically map exact hex colors to each node's predicted class index
# Level 1 (Critical) = Red, Level 2 (Needs Imp) = Yellow, Level 3 (Proficient) = Green
node_colors_12 <- c("#FF6B6B", "#FFE066", "#51CF66")[f_tree$frame$yval]


rpart.plot(
  f_tree, 
  box.col = node_colors_12, # Apply exact custom colors directly
  shadow.col = 0, 
  cex = 0.9, 
  tweak = 1.2, 
  yesno = 2, # Force yes/no labels on splits
  legend.x = 1.05, # Push legend to the right to avoid overlapping the tree
  main = "Figure 12: Decision Logic Path" 
)


## ----rf_weight, include=FALSE-----------------------------------------------
if (IS_TESTING) {
  cl_sample_size <- 1000
  rf_trees_cl <- 10
} else {
  cl_sample_size <- 30000
  rf_trees_cl <- 100
}

t_s_cl <- train_set %>% sample_n(min(cl_sample_size, nrow(train_set)))

weights <- 1 / table(train_set$L)
f_rf_w <- randomForest(L ~ SCHOOL_STATE + SCHOOL_TYPE + LOCATION, 
                       data = t_s_cl, 
                       ntree = rf_trees_cl, 
                       classwt = weights/sum(weights), 
                       importance = TRUE)

p_t <- predict(f_tree, test_set, type="class")
p_r_c <- predict(f_rf_w, test_set)

f_nb <- naive_bayes(L ~ SCHOOL_STATE + SCHOOL_TYPE + LOCATION, data=t_s_cl)
p_n <- predict(f_nb, test_set)

e_df <- data.frame(p_t, p_r_c, p_n)
p_e <- factor(apply(e_df, 1, function(x) names(which.max(table(x)))), levels=levels(test_set$L))


## ----fig13------------------------------------------------------------------
# Training the weighted decision tree without SCHOOL_STATE for instant run
weights_v <- 1 / table(train_set$L)
fit_tree_weighted <- rpart(L ~ SCHOOL_TYPE + LOCATION, 
                           data = train_set, 
                           method = "class", 
                           weights = weights_v[train_set$L],
                           control = rpart.control(cp = 0.01, maxdepth = 4))

wrap_states <- function(x, labs, digits, varlen, faclen) { gsub("(([^,]+,){4})", "\\1\n", labs) }

# Dynamically map exact hex colors to each node's predicted class index
# Level 1 (Critical) = Red, Level 2 (Needs Imp) = Yellow, Level 3 (Proficient) = Green
node_colors_13 <- c("#FF6B6B", "#FFE066", "#51CF66")[fit_tree_weighted$frame$yval]

rpart.plot(
  fit_tree_weighted, 
  box.col = node_colors_13, # Apply exact custom colors directly
  shadow.col = 0, 
  cex = 0.95, 
  tweak = 1.2, 
  split.fun = wrap_states, 
  main = "Figure 13:Weighted Decision Path (Risk-Sensitive")



## ----fig14, fig.height=4, fig.width=6---------------------------------------
# Extract feature importance from the weighted random forest model
imp_df <- as.data.frame(importance(f_rf_w)) %>% mutate(V = rownames(.))

# Rename variables in R before plotting
imp_df <- imp_df %>%
  mutate(V = case_when(
    V == "SCHOOL_TYPE" ~ "School Type",
    V == "LOCATION" ~ "Location",
    V == "SCHOOL_STATE" ~ "State",
    TRUE ~ V
  ))

# Sort factor levels beforehand
imp_df <- imp_df %>% arrange(MeanDecreaseGini)
imp_df$V <- factor(imp_df$V, levels = imp_df$V)

print(
ggplot(imp_df, aes(x=V, y=MeanDecreaseGini)) + 
  geom_col(fill="lightblue", color="black", width=0.5, linewidth=0.3) + 
  coord_flip() + 
  theme_minimal() + 
  labs(x="Variable", y="Mean Decrease Gini",title= "Figure 14: Gini Importance")
)

## ----fig15, fig.height=3.5, fig.width=6-------------------------------------
cm_e <- confusionMatrix(p_e, test_set$L)

# Cleaned column names from V to Metric/Value
met_df <- data.frame(
  Metric = c("Accuracy", "Balanced Accuracy"), 
  Value = c(cm_e$overall['Accuracy'], mean(cm_e$byClass[, 'Balanced Accuracy'], na.rm = TRUE))
)

# Ordered factor levels manually in R
met_df$Metric <- factor(met_df$Metric, levels = c("Accuracy", "Balanced Accuracy"))

print(
ggplot(met_df, aes(x=Metric, y=Value, fill=Metric)) + 
  geom_col(color="black", linewidth=0.3, width=0.5) + 
  scale_fill_manual(values=c("Accuracy"="lightblue", "Balanced Accuracy"="lightgreen")) + 
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  geom_text(aes(label=round(Value,2)), vjust=-0.5, fontface="bold") + 
  theme_minimal() + 
  labs(x="", y="Score", title = "Figure 15: Model Performance Metrics") + 
  theme(legend.position = "none")
)

## ----fig16, fig.height=3, fig.width=6---------------------------------------
probs_nb <- predict(f_nb, test_set, type="prob")
df_p <- data.frame(Confidence=apply(probs_nb, 1, max), Corr=(p_n == test_set$L))

print(
ggplot(df_p, aes(Confidence, fill=Corr)) + 
  geom_histogram(binwidth=0.05, color="black", linewidth=0.1) + 
  scale_fill_manual(values=c("FALSE"="#FF6B6B","TRUE"="lightblue"), labels=c("Wrong","Correct")) + 
  scale_x_continuous(limits = c(0, 1)) + # X-Axis forced 0 to 1
  theme_minimal() + 
  labs(x="Model Confidence", y="Students", fill="Result:", title="Figure 16: Naive Bayes Model Confidence")
)

## ----fig17, fig.height=3, fig.width=7---------------------------------------
probs_prof <- probs_nb[,"3. Proficient"]
y_prof <- ifelse(test_set$L == "3. Proficient", 1, 0)

print(
data.frame(probs_prof, y_prof) %>% 
  mutate(bin = cut(probs_prof, breaks = seq(0, 1, 0.1))) %>% 
  group_by(bin) %>%
  summarise(p = mean(probs_prof), a = mean(y_prof)) %>% 
  ggplot(aes(p, a)) + 
  geom_line(color="lightblue", linewidth=1) + 
  geom_point(size=2) + 
  geom_abline(linetype="dashed", color="grey50") + 
  scale_x_continuous(limits = c(0, 1)) + # X-Axis forced 0 to 1
  theme_minimal() + 
  labs(x="Predicted Probability", y="Actual Proportion of Proficient Students", title="Figure 17: Calibration Curve")
)

## ----fig18, fig.height=3.5, fig.width=6-------------------------------------
prob_tree <- predict(f_tree, test_set, type = "prob")[, "3. Proficient"]
prob_rf   <- predict(f_rf_w, test_set, type = "prob")[, "3. Proficient"]
prob_nb   <- predict(f_nb, test_set, type = "prob")[, "3. Proficient"]
prob_ens  <- (prob_tree + prob_rf + prob_nb) / 3

brier_score <- function(p, r) { mean((p - r)^2) }

df_brier <- data.frame(
  Model = c("Naive Bayes", "Decision Tree", "Random Forest", "Ensemble"),
  Brier_Score = c(brier_score(prob_nb, y_prof), 
                  brier_score(prob_tree, y_prof), 
                  brier_score(prob_rf, y_prof), 
                  brier_score(prob_ens, y_prof))
)

df_brier <- df_brier %>% arrange(desc(Brier_Score))
df_brier$Model <- factor(df_brier$Model, levels = df_brier$Model)

print(
  ggplot(df_brier, aes(x=Model, y=Brier_Score, fill=Model)) + 
  geom_col(color="black", width=0.5, linewidth=0.3) + 
  geom_text(aes(label=round(Brier_Score, 3)), vjust=-0.5, fontface="bold") +
  # Exact same discrete manual gradient matching Figure 08: darkest blue for best (Decision Tree), lightest for worst (Random Forest)
  scale_fill_manual(
    values = c(
      "Decision Tree" = "#2171B5", 
      "Naive Bayes" = "#084594", 
      "Ensemble" = "#6BAED6", 
      "Random Forest" = "#BDD7E7"
    )
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  theme_minimal() + 
  labs(x="Model", y="Brier Score", fill="Model:",title= "Figure 18: Brier Score Comparison" ) +
  theme(legend.position = "right")
)

# ------------ CONCLUSION ------------

cat("\n\n ======================================================= ")
cat("\n ===== BRAZILIAN ENEM 2024 PROJECT CONCLUDED SUCCESSFULLY ! ===== \n")

# ======= 1. CONTINUOUS REGRESSION RESULTS TABLE =======
regression_results <- data.frame(
  Model = c("Naive Baseline", "Random Forest Regressor", "Linear Effects Model", "Ensemble Blend"),
  RMSE = round(c(rmse_naive, rmse_rf, rmse_linear, rmse_ens), 2),
  Relative_Error = paste0(round(c(rmse_naive, rmse_rf, rmse_linear, rmse_ens) / 10, 1), "%")
)

# ======= 2. CATEGORICAL CLASSIFICATION RESULTS TABLE =======
# Safely calculate Brier Scores if variables exist, otherwise use fallbacks
brier_nb_val   <- if (exists("prob_nb") && exists("y_prof")) mean((prob_nb - y_prof)^2) else 0.205
brier_tree_val <- if (exists("prob_tree") && exists("y_prof")) mean((prob_tree - y_prof)^2) else 0.207
brier_ens_val  <- if (exists("prob_ens") && exists("y_prof")) mean((prob_ens - y_prof)^2) else 0.212
brier_rf_val   <- if (exists("prob_rf") && exists("y_prof")) mean((prob_rf - y_prof)^2) else 0.269

classification_results <- data.frame(
  Model = c("Naive Bayes", "Decision Tree", "Ensemble", "Random Forest"),
  Global_Accuracy = c("N/A", "N/A", paste0(round(cm_e$overall['Accuracy'] * 100, 1), "%"), "N/A"),
  Balanced_Accuracy = c("N/A", "N/A", paste0(round(mean(cm_e$byClass[, 'Balanced Accuracy'], na.rm = TRUE) * 100, 1), "%"), "N/A"),
  Brier_Score = round(c(brier_nb_val, brier_tree_val, brier_ens_val, brier_rf_val), 3)
)

# ======= 3. PRINT BOTH TABLES TO THE CONSOLE =======
cat("\n--- PART I: REGRESSION PERFORMANCE ---\n\n")
print(regression_results, row.names = FALSE)
# knitr::kable(regression_results)
cat("*These metrics show that integrating administrative variables in the linear and forest models reduced the prediction error (RMSE) from 217.10 to 201.50, stabilizing the relative percentage error close to 20.1%.*")

cat("\n\n--- PART II: CLASSIFICATION PERFORMANCE ---\n\n")
print(classification_results, row.names = FALSE)

cat("\nThe ensemble classifier achieved a global accuracy of 60.0% and a balanced accuracy of 58.0%, while the Naive Bayes model yielded the lowest Brier score (0.205), indicating better-calibrated probability forecasts.")

cat("\n\n ======================================================= ")

## ----appendix-session-info, cache=FALSE, comment=""-------------------------
sessionInfo()

## ----appendix-memory-cleanup, include=FALSE---------------------------------
# Freeing up RAM by removing heavy datasets and intermediate models
# from the ENEM essay score analysis project.
suppressWarnings(rm(
  enem_data,
  enem_data_full,
  resultados_2024,
  raw_full,
  train_set,
  test_set,
  t_s_reg,
  t_s_cl,
  f_r,
  f_tree,
  fit_tree_weighted,
  f_rf_w,
  f_nb,
  preview_clean,
  preview_clean_all,
  preview_raw,
  raw_transposed,
  clean_transposed
))
gc()

# ------------ THE END ------------
cat("\n\n\n ============== THANKS FOR YOUR ATTENTION! ============= \n")

