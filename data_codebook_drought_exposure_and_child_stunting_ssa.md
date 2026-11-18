# Codebook: Drought Exposure and Child Stunting in Sub-Saharan Africa

* **Output Dataset:** `data/analysis/kids_merged.rds`
* **Unit of Observation:** Living child under age 5 (`b5 == 1`) with valid anthropometry (`hw70 < 9990`) and valid cluster GPS coordinates (`!(LATNUM == 0 & LONGNUM == 0)`).
* **Sources:** DHS Children's Recode (`KR`) & Geographic (`GE`) files (standard DHS surveys $\ge 2010$), CSIC SPEIbase (`spei01.nc`, 1-month timescale), and IFPRI MapSPAM 2020 (`v2r2` global harvested area).

---
# General Notes
Opted as 2010 for a cutoff. Keeps the survey data within roughly a decade of the 2020 MapSPAM cropland snapshot, so the agricultural conditions we attach to each cluster plausibly reflect those children experienced in early life. It also limits the sample to DHS-6 and later surveys, which share comparable variable definitions.

File      Survey	                          Why dropped
OSKR01DT	Ondo State, Nigeria, 1986	        Too old
SDKR01DT	Sudan, 1989–90	                  Too old
CFKR31DT	Central African Republic, 1994–95	Too old
SZKR51DT	Eswatini, 2006–07	                Too old
STKR51DT	São Tomé, 2008–09	                Too old, no GPS
CGKR61DT	Congo	                            No GPS file
LBKR7ADT	Liberia	                          No GPS file
MDKR81DT	Madagascar	                      No GPS file
KEKR91DT	Kenya (latest)	                  No GPS file


## 1. Identifiers, Survey Design, and Weights

| Variable | Source / Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `kr_file` | `bind_rows(.id)` | Character | Source DHS Children's Recode filename (e.g., `"AOKR71FL.DTA"`). |
| `cc` | `substr(v000, 1, 2)` | Character | 2-letter DHS country code (e.g., `"AO"`, `"KE"`). |
| `cluster_id` | `paste(cc, v001, sep = "_")` | Character | Unique cluster identifier across all pooled surveys. |
| `child_id` | `paste(cc, caseid, bidx, sep = "_")` | Character | Unique child identifier across all pooled surveys. |
| `caseid` | DHS `KR` | Character | Household/mother case identification string within a survey. |
| `bidx` | DHS `KR` | Numeric | Birth column index (distinguishes siblings/twins under age 5). |
| `v000` | DHS `KR` | Character | Country code and DHS phase (e.g., `"AO7"`). |
| `v001` | DHS `KR` | Numeric | Cluster number (matches `DHSCLUST` in `GE` shapefile). |
| `v002` | DHS `KR` | Numeric | Household number within cluster. |
| `v005` | DHS `KR` | Numeric | Raw women's/children's individual sample weight (6 implied decimals). |
| `wt` | `v005 / 1e6` | Numeric | Rescaled individual sampling weight (`v005 / 1,000,000`). |
| `v021` | DHS `KR` | Numeric | Primary sampling unit (PSU). |
| `v022` | DHS `KR` | Numeric | Sample strata for sampling errors. |
| `v024` | DHS `KR` | Numeric | Subnational region code (country-specific). |
| `v025` | DHS `KR` | Numeric | Type of place of residence (`1` = Urban, `2` = Rural). |
| `v006` | DHS `KR` | Numeric | Month of interview (`1`–`12`). |
| `v007` | DHS `KR` | Numeric | Year of interview (4-digit calendar year). |
| `v008` | DHS `KR` | Numeric | Date of interview in Century Month Code (`CMC`: months since Jan 1900). |

---

## 2. Child Outcomes and Demographics

| Variable | Source / Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `hw70` | DHS `KR` | Numeric | Raw Height-for-Age Z-score (WHO child growth standards $\times 100$; codes $\ge 9990$ excluded). |
| `haz` | `hw70 / 100` | Numeric | **Primary continuous outcome:** Height-for-Age Z-score (SD units). |
| `stunted` | `factor(haz < -2)` | Factor | **Primary binary outcome:** Child is stunted (`"yes"` if `haz < -2.0`, `"no"` otherwise). |
| `b3` | DHS `KR` | Numeric | Child's date of birth in Century Month Code (`CMC`). |
| `b5` | DHS `KR` | Numeric | Child is alive (`1` = Yes; filtered to `1` in analytic sample). |
| `hw1` | DHS `KR` | Numeric | Raw child's age in months. |
| `age_months` | `hw1` | Numeric | Child's age in completed months (`0`–`59`). |
| `hw13` | DHS `KR` | Numeric | Result of height/weight measurement (`0` = Measured). |
| `b4` | DHS `KR` | Numeric | Raw sex of child (`1` = Male, `2` = Female). |
| `male` | `as.integer(b4 == 1)` | Integer | Indicator for male child (`1` = Male, `0` = Female). |
| `bord` | DHS `KR` | Numeric | Birth order number (`1` = First birth, `2` = Second, etc.). |
| `b0` | DHS `KR` | Numeric | Raw multiple birth code (`0` = Single birth, `1` = 1st of multiple, etc.). |
| `twin` | `as.integer(b0 > 0)` | Integer | Indicator for multiple birth / twin (`1` = Twin/multiple, `0` = Singleton). |
| `b11` | DHS `KR` | Numeric | Raw preceding birth interval in months (`NA` for first births). |
| `first_birth` | `as.integer(is.na(b11))` | Integer | Indicator for first-born child (`1` = First birth, `0` = Subsequent birth). |
| `birth_int` | `replace_na(b11, 0)` | Numeric | Preceding birth interval in months (`0` for first births; use alongside `first_birth`). |
| `m19` | DHS `KR` | Numeric | Raw birth weight in grams (`9996` = Not weighed, `9998` = Don't know). |
| `birth_wt_kg` | `na_if_ge(m19, 9000) / 1000` | Numeric | Birth weight in kilograms (`NA` if not weighed or unknown). |
| `m18` | DHS `KR` | Numeric | Raw maternal recall of size at birth (`1`–`5`, `8` = Don't know). |
| `size_birth` | `na_if_ge(m18, 8)` | Numeric | Perceived size at birth (`1` = Very large, `2` = Larger than average, `3` = Average, `4` = Smaller than average, `5` = Very small). |

---

## 3. Maternal and Partner Characteristics

| Variable | Source / Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `v011` | DHS `KR` | Numeric | Mother's date of birth in Century Month Code (`CMC`). |
| `v012` | DHS `KR` | Numeric | Mother's current age in completed years (`15`–`49`). |
| `mom_age_birth` | `(b3 - v011) / 12` | Numeric | Mother's age in years at the time of the child's birth. |
| `v438` | DHS `KR` | Numeric | Raw maternal height in millimeters (`9994`–`9999` = Missing/flagged). |
| `mom_height_cm` | `na_if_ge(v438, 9990) / 10` | Numeric | Mother's height in centimeters. |
| `v445` | DHS `KR` | Numeric | Raw maternal Body Mass Index ($\text{kg/m}^2 \times 100$). |
| `mom_bmi` | `na_if_ge(v445, 9990) / 100` | Numeric | Mother's Body Mass Index ($\text{kg/m}^2$). |
| `v106` | DHS `KR` | Numeric | Mother's highest educational level (`0` = None, `1` = Primary, `2` = Secondary, `3` = Higher). |
| `v133` | DHS `KR` | Numeric | Raw maternal education in single years (`97`–`99` = Missing/DK). |
| `mom_educ_yrs` | `na_if_ge(v133, 97)` | Numeric | Mother's completed years of education. |
| `v501` | DHS `KR` | Numeric | Raw current marital/union status (`0`–`5`). |
| `has_partner` | `as.integer(v501 %in% c(1, 2))` | Integer | Indicator for married or living with a partner (`1` = Yes, `0` = No). |
| `v701` | DHS `KR` | Numeric | Partner's highest educational level (`0`–`3`, `8` = DK). |
| `v715` | DHS `KR` | Numeric | Raw partner's education in single years (`97`–`99` = Missing/DK). |
| `partner_educ` | `na_if_ge(v715, 97)` | Numeric | Partner's completed years of education (`NA` if no partner or unknown). |
| `v201` | DHS `KR` | Numeric | Total children ever born to mother. |
| `v206` | DHS `KR` | Numeric | Total sons who have died. |
| `v207` | DHS `KR` | Numeric | Total daughters who have died. |
| `child_deaths` | `v206 + v207` | Numeric | Total number of mother's children who have died. |
| `v212` | DHS `KR` | Numeric | Mother's age at first birth (years). |

---

## 4. Household WASH, Assets, Demographics, and Healthcare Access

| Variable | Source / Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `v190` | DHS `KR` | Numeric | Within-survey wealth index quintile (`1` = Poorest to `5` = Richest). |
| `v191` | DHS `KR` | Numeric | Raw within-survey wealth index factor score (5 implied decimals). |
| `wealth_z` | `scale(v191)` grouped by `cc` | Numeric | Standardized within-survey wealth z-score ($\mu = 0, \sigma = 1$ per survey). |
| `v113` | DHS `KR` | Numeric | Raw source of drinking water code. |
| `improved_water` | `v113 %in% c(10:14, 20, 21, 30, 31, 40, 41, 51, 61, 62, 71, 91, 92)` | Integer | Improved drinking water source (`1` = Improved, `0` = Unimproved). |
| `v115` | DHS `KR` | Numeric | Raw time to get to water source (`996` = On premises, `997`–`999` = DK/Missing). |
| `water_mins` | `case_when(v115 == 996 ~ 0, v115 >= 997 ~ NA, ...)` | Numeric | Round-trip travel time to water source in minutes (`0` if on premises). |
| `v116` | DHS `KR` | Numeric | Raw type of toilet facility code. |
| `improved_toilet`| `v116 %in% c(10:13, 15, 20:22, 41)` | Integer | Improved sanitation facility (`1` = Improved, `0` = Unimproved). |
| `v160` | DHS `KR` | Numeric | Raw toilet facility shared with other households (`0` = No, `1` = Yes). |
| `shared_toilet` | `as.integer(v160 == 1)` | Integer | Indicator for shared toilet facility (`1` = Shared, `0` = Private/NA). |
| `v161` | DHS `KR` | Numeric | Raw type of cooking fuel code. |
| `clean_fuel` | `as.integer(v161 %in% 1:4)` | Integer | Clean cooking fuel (`1` = Electricity, LPG, natural gas, or biogas; `0` = Solid/other fuel). |
| `v119` / `electricity` | `as.integer(v119 == 1)` | Integer | Household has electricity (`1` = Yes, `0` = No). |
| `v120` / `radio` | `as.integer(v120 == 1)` | Integer | Household has a radio (`1` = Yes, `0` = No). |
| `v121` / `tv` | `as.integer(v121 == 1)` | Integer | Household has a television (`1` = Yes, `0` = No). |
| `v122` / `fridge` | `as.integer(v122 == 1)` | Integer | Household has a refrigerator (`1` = Yes, `0` = No). |
| `v127` | DHS `KR` | Numeric | Raw main floor material code (`10`s = Natural, `20`s = Rudimentary, `30`s = Finished). |
| `finished_floor` | `as.integer(v127 >= 30 & v127 < 96)` | Integer | Finished flooring material (`1` = Finished floor, `0` = Natural/rudimentary). |
| `urban` | `as.integer(v025 == 1)` | Integer | Urban residence indicator (`1` = Urban, `0` = Rural). |
| `v136` / `hh_size` | DHS `KR` | Numeric | Total number of de jure/de facto household members. |
| `v137` / `n_under5` | DHS `KR` | Numeric | Number of children aged 5 and under in the household. |
| `v151` | DHS `KR` | Numeric | Raw sex of household head (`1` = Male, `2` = Female). |
| `female_head` | `as.integer(v151 == 2)` | Integer | Female-headed household indicator (`1` = Female, `0` = Male). |
| `v152` | DHS `KR` | Numeric | Raw age of household head (`97`–`99` = DK/Missing). |
| `head_age` | `na_if_ge(v152, 97)` | Numeric | Age of household head in years. |
| `v745b` | DHS `KR` | Numeric | Raw land ownership status (`0` = Does not own, `1` = Alone, `2` = Jointly, `3` = Both). |
| `owns_land` | `as.integer(v745b %in% 1:3)` | Integer | Respondent owns agricultural/other land alone or jointly (`1` = Yes, `0` = No). |
| `v467d` | DHS `KR` | Numeric | Raw distance to health facility barrier (`1` = Big problem, `2` = Not a big problem). |
| `distance_problem`| `as.integer(v467d == 1)` | Integer | Distance to health facility reported as a big problem (`1` = Yes, `0` = No). |
| `v481` | DHS `KR` | Numeric | Raw health insurance coverage (`0` = No, `1` = Yes). |
| `insured` | `as.integer(v481 == 1)` | Integer | Respondent is covered by health insurance (`1` = Yes, `0` = No). |

---

## 5. Cluster Geographic Metadata (`GE` Shapefiles)

| Variable | Source / Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `DHSCC` | DHS `GE` | Character | 2-letter DHS country code. |
| `DHSCLUST` | DHS `GE` | Numeric | Cluster number within survey. |
| `URBAN_RURA` | DHS `GE` | Character | Cluster urban/rural designation (`"U"` = Urban, `"R"` = Rural). |
| `LATNUM` | DHS `GE` | Numeric | Cluster latitude in decimal degrees (WGS84; displaced up to 2 km urban / 5 km rural). |
| `LONGNUM` | DHS `GE` | Numeric | Cluster longitude in decimal degrees (WGS84; displaced up to 2 km urban / 5 km rural). |
| `ALT_DEM` | DHS `GE` | Numeric | Cluster elevation in meters above sea level from Digital Elevation Model. |

---

## 6. Child-Specific SPEI Drought Exposure Windows (`spei01.nc`)

Extracted at cluster coordinates (`LATNUM`, `LONGNUM`) from the `0.5°` monthly SPEIbase dataset (`2005-01` through `2024-12`), matched to four developmental windows (all capped at `v008 - 1` so post-interview months are never included):
* **`utero`:** In-utero period (`b3 - 9` to `b3 - 1`; 9 months prior to birth).
* **`yr1`:** First year of life (`b3` to `min(b3 + 11, v008 - 1)`; birth through 11 months).
* **`yr2`:** Second year of life (`b3 + 12` to `min(b3 + 23, v008 - 1)`; `NA` for children `< 12` months old at interview).
* **`rec`:** Recent exposure (`v008 - 12` to `v008 - 1`; 12 months immediately preceding interview).

| Variable | Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `spei_mean_utero` | `mean(spei)` over `utero` | Numeric | Mean 1-month SPEI during the 9 months prior to birth (negative = drier than normal). |
| `spei_mean_yr1` | `mean(spei)` over `yr1` | Numeric | Mean 1-month SPEI during the child's first year of life. |
| `spei_mean_yr2` | `mean(spei)` over `yr2` | Numeric | Mean 1-month SPEI during the child's second year of life (`NA` if `< 12` months old). |
| `spei_mean_rec` | `mean(spei)` over `rec` | Numeric | Mean 1-month SPEI during the 12 months prior to interview. |
| `drought_share_utero`| `mean(spei < -1)` over `utero`| Numeric | Proportion of in-utero months experiencing moderate/severe drought ($\text{SPEI} < -1.0$). |
| `drought_share_yr1` | `mean(spei < -1)` over `yr1` | Numeric | Proportion of first-year months experiencing moderate/severe drought ($\text{SPEI} < -1.0$). |
| `drought_share_yr2` | `mean(spei < -1)` over `yr2` | Numeric | Proportion of second-year months experiencing moderate/severe drought ($\text{SPEI} < -1.0$). |
| `drought_share_rec` | `mean(spei < -1)` over `rec` | Numeric | Proportion of recent 12 months experiencing moderate/severe drought ($\text{SPEI} < -1.0$). |
| `n_months_utero` | `sum(!is.na(spei))` over `utero`| Integer | Count of observed SPEI months in `utero` window (max `9`). |
| `n_months_yr1` | `sum(!is.na(spei))` over `yr1` | Integer | Count of observed SPEI months in `yr1` window (max `12`; lower if `< 12` mos old or post-2024). |
| `n_months_yr2` | `sum(!is.na(spei))` over `yr2` | Integer | Count of observed SPEI months in `yr2` window (max `12`; `NA` if `< 12` mos old). |
| `n_months_rec` | `sum(!is.na(spei))` over `rec` | Integer | Count of observed SPEI months in `rec` window (max `12`; lower for Rwanda 2025). |

---

## 7. Local Agricultural Exposure (MapSPAM 2020, 10 km Cluster Buffer)

Extracted as the mean harvested area (hectares per 5-arcminute grid cell, ~9 km) within a **10 km radius buffer** (`st_buffer(gps, dist = 10000)`) around each DHS cluster.

| Variable | Derivation | Type | Description & Coding |
| :--- | :--- | :--- | :--- |
| `crop_ha_mean` | Mean of `crop_ha` (`H_TA`, `whea:rubb`) in 10 km buffer | Numeric | Mean total harvested cropland area (hectares/cell, all technologies) within 10 km of cluster. |
| `staple_ha_mean` | Mean of `staple_ha` (`H_TA`, 11 staple crops) in 10 km buffer | Numeric | Mean harvested area (hectares/cell) of major staple crops (`maiz`, `sorg`, `mill`, `pmil`, `rice`, `whea`, `cass`, `yams`, `swpo`, `pota`, `bean`) within 10 km. |
| `rainfed_ha` | Mean of `rainfed_ha` (`H_TR`, `whea:rubb`) in 10 km buffer | Numeric | Mean rainfed harvested cropland area (hectares/cell, all crops) within 10 km of cluster. |
| `rainfed_share` | `rainfed_ha / crop_ha_mean` | Numeric | Share of local harvested cropland that is rainfed (`0`–`1`; `NaN`/`NA` where `crop_ha_mean == 0`). |