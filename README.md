
# Brazilian ENEM 2024 Essay Score Analysis Project

## HarvardX: PH125.9x Data Science Capstone

This repository contains the complete machine learning project evaluating the predictive limits of high-level administrative metadata—specifically school type, location, and state coordinates—on essay scores from the 2024 Brazilian National High School Exam (ENEM).

## Project Overview

The core objective is to rigorously evaluate whether macro-level school descriptors are mathematically sufficient to predict complex, human-graded student writing outcomes. 

The study implements a two-part supervised learning framework:
1. **Part I (Continuous Regression)**: Predicts exact continuous essay scores (0–1000 scale), establishing expected baseline scores and sequential linear effects models, optimized random forests, and ensemble blends.
2. **Part II (Categorical Classification)**: Discretizes scores into three actionable proficiency tiers (Critical, Needs Improvement, and Proficient) using decision trees, naive Bayes, and weighted random forests to handle severe class imbalance.

Furthermore, this analysis defines a statistical predictive ceiling, demonstrating why highly granular individual socioeconomic metrics—currently restricted under Brazilian General Data Protection Law (LGPD)—are required to capture further writing nuances.


## Data Source & Disclaimer

### Original Primary Source
The original, complete, and un-sampled microdata containing 4,332,944 student records from the 2024 ENEM exam is published and maintained by the **National Institute for Educational Studies and Research Anísio Teixeira (INEP)**, under the Ministry of Education (MEC) of the Federal Government of Brazil.

* **Publisher**: National Institute for Educational Studies and Research Anísio Teixeira (INEP)
* **Official Data Portal**: [INEP Microdata Portal](https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/enem)
* **Direct Zip Download URL**: [Official INEP 2024 ENEM ZIP](https://download.inep.gov.br/microdados/microdados_enem_2024.zip)

### Sampled Dataset Disclaimer
To comply with GitHub's file size limits (maximum 100 MB per file) and ensure a reproducible, fast-running execution for peer grading, this repository hosts a **5% random sample** of the original `RESULTADOS_2024.csv` dataset. 

This sample was extracted using a reproducible random seed (`set.seed(2024)`) in R. No academic, geographic, or administrative variables were altered during this process. This allows peer reviewers to download, extract, and execute the entire machine learning pipeline in less than 10 seconds.




---

## Performance Summary

### Part I: Continuous Regression Performance

| Model / Regression Method | RMSE (0-1000 Scale) | Relative Error (%) |
| :--- | :---: | :---: |
| **Naive Baseline** | 217.10 | 21.7% |
| **Random Forest Regressor** | 202.00 | 20.2% |
| **Linear Effects Model** | 201.90 | 20.2% |
| **Ensemble Blend** | 201.50 | 20.1% |

*Interpretation: Integrating administrative variables reduced the prediction error (RMSE) to 201.50, stabilizing the relative percentage error close to 20.1% (highly comparable to the classic MovieLens rating benchmark of 17.3%).*

### Part II: Categorical Classification Performance & Calibration

| Model / Classifier | Global Accuracy | Balanced Accuracy | Brier Score (Calibration Error) |
| :--- | :---: | :---: | :---: |
| **Naive Bayes** | N/A | N/A | 0.205 |
| **Decision Tree** | N/A | N/A | 0.207 |
| **Ensemble Classifier** | 60.0% | 58.0% | 0.212 |
| **Random Forest** | N/A | N/A | 0.269 |

*Interpretation: The ensemble classifier achieved a global accuracy of 60.0% and a balanced accuracy of 58.0%. Decision tree and naive Bayes models achieved the lowest Brier scores, indicating highly reliable, well-calibrated probability forecasts.*

---

## Tech Stack & Libraries
* **Language**: R
* **Machine Learning & Stats**: `dplyr`, `tidyr`, `caret`, `randomForest`, `rpart`, `rpart.plot`, `naivebayes`, `broom`, `scales`
* **Visualization & Formatting**: `ggplot2`, `patchwork`, `gridExtra`, `kableExtra`

---

## How to Run & Reproduce

### 1. Requirements
Ensure you have R and RStudio installed. The script automatically checks, installs, and loads any missing packages from CRAN:

### 2. Prototyping Mode (Fast Run)
To run and test the complete pipeline in a few seconds on a sample of 10,000 records, set the prototyping switch to `TRUE` in the script's global options:
```R
IS_TESTING <- TRUE
```
For the final complete run on the full population (~1.19 million records), set the switch to `FALSE`:
```R
IS_TESTING <- FALSE
```

### 3. Execution
Run the complete code directly from your RStudio console:
```R
source("BRAZILIAN ENEM CAPSTONE - TIZZO", echo = TRUE)
```
*Note: If the raw data is not found locally, the script automatically downloads and extracts the raw ENEM 2024 microdata (~700MB ZIP) directly from the official INEP repository.*

---

## Author
* **Michell Pereira Tizzo**
* Electrical Engineer, Petroleum Engineering Specialist, and Project Manager.
* GitHub: [github.com/mtiz10](https://github.com/mtiz10)
```

---
