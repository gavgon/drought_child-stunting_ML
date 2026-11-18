# -----------------------------------------------------------------------------
# AI Disclaimer:
# Portions of this extraction script and joins were created with
# the aid of Google Gemini Edu 4 Hydrogen at the direction of the author.
# DHS variables/indices were created and updated by the author as per
# the DHS STANDARD RECODE MANUAL.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# 0. Packages
# -----------------------------------------------------------------------------
# install.packages(c("tidyverse", "rdhs", "sf", "terra", "haven"))

library(tidyverse)
library(rdhs)
library(sf)
library(terra)    
library(haven)

# -----------------------------------------------------------------------------
# 1. DHS login (you will be prompted for your password)
# -----------------------------------------------------------------------------
set_rdhs_config(
  email   = "gag103@georgetown.edu",
  project = "Data Science for Public Policy Final Project — Drought Exposure and Child Stunting"
)


# -----------------------------------------------------------------------------
# 2. Choose surveys
# -----------------------------------------------------------------------------
# Most recent standard DHS per SSA country ...
ssa_countries <- c(
  "AO", "BJ", "BF", "BU", "CM", "CF", "TD", "KM", "CG", "CD",
  "CI", "SZ", "ET", "GA", "GM", "GH", "GN", "KE", "LS", "LR",
  "MG", "MW", "ML", "MR", "MZ", "NM", "NI", "NG", "RW",
  "ST", "SN", "SL", "ZA", "SD", "TZ", "TG", "UG", "ZW", "ZM"
)

recent_surveys <- dhs_surveys(countryIds = ssa_countries, surveyType = "DHS") |>
  group_by(DHS_CountryCode) |>
  slice_max(order_by = as.numeric(SurveyYear), n = 1) |>
  ungroup()

# ... then keep only surveys that are 2010 or later and released GPS.
gps_datasets <- dhs_datasets(
  surveyIds = recent_surveys$SurveyId,
  fileType  = "GE"                      # cluster GPS coordinates
)

surveys_use <- recent_surveys |>
  filter(as.numeric(SurveyYear) >= 2010,
         SurveyId %in% gps_datasets$SurveyId)

nrow(surveys_use)   # expect about 31

# -----------------------------------------------------------------------------
# 3. Download KR (children) and GE (GPS) files
# -----------------------------------------------------------------------------
# rdhs caches downloads, so re-running this does not re-download.
datasets <- dhs_datasets(
  surveyIds  = surveys_use$SurveyId,
  fileType   = "KR",                     # Children's Recode
  fileFormat = "DT"                      # Stata .dta
)
local_paths <- get_datasets(datasets$FileName)

gps_use <- gps_datasets |> filter(SurveyId %in% surveys_use$SurveyId)
gps_zip_paths <- get_datasets(gps_use$FileName, download_option = "zip")

dir.create("dhs_gps_unzipped", showWarnings = FALSE)
walk(gps_zip_paths, \(z) unzip(z, exdir = "dhs_gps_unzipped"))


# -----------------------------------------------------------------------------
# 4. Extract the variables we need from every KR file
# -----------------------------------------------------------------------------
# Dropped after the coverage check: v483a (16/31 surveys), v040 (27/31; we use
# GPS elevation instead), v104 (26/31).
my_vars <- c(
  # IDs, survey design, dates
  "caseid","bidx","v000","v001","v002","v005","v021","v022","v024","v025",
  "v006","v007","v008","b3",
  # outcome + sample definition
  "hw70","hw1","b5","hw13",
  # child
  "b4","bord","b0","b11","m18","m19",
  # mother
  "v011","v012","v106","v133","v438","v445","v501","v201","v206","v207","v212",
  # household
  "v136","v137","v151","v152","v190","v191","v113","v115","v116","v160",
  "v161","v119","v120","v121","v122","v127",
  # access, land, partner
  "v467d","v481","v745b","v701","v715"
)

qs <- search_variables(datasets$FileName, variables = my_vars)

# Coverage check: number of surveys containing each variable (want ~31)
qs |> count(variable, sort = TRUE) |> as_tibble() |> print(n = Inf)

extracted_list <- extract_dhs(qs, add_geo = FALSE)

# Stack all surveys into one data frame.
# rbind_labelled() fails when surveys have different columns (v438/v445/v745b are missing in one survey) or conflicting labels, so strip the value labels
# first and use bind_rows(), which fills missing columns with NA.
# We recode from the numeric codes in step 5 anyway.
extracted_list <- map(extracted_list, \(df) df |>
                        zap_labels() |>
                        mutate(across(everything(), as.vector)))
kr <- bind_rows(extracted_list, .id = "kr_file")


# -----------------------------------------------------------------------------
# 5. Analysis sample + clean special codes
# -----------------------------------------------------------------------------
# DHS uses codes like 9996/9998 (and 97/98 for "don't know") instead of NA.
na_if_ge <- function(x, cutoff) if_else(x >= cutoff, NA_real_, as.numeric(x))

kids <- kr |>
  zap_labels() |>                                  # plain numbers from here on
  # living children with a valid height-for-age score
  filter(b5 == 1, !is.na(hw70), hw70 < 9990) |>
  mutate(
    # keys -------------------------------------------------------------------
    cc         = substr(v000, 1, 2),               # DHS country code, e.g. "AO"
    cluster_id = paste(cc, v001, sep = "_"),       # unique cluster across surveys
    child_id   = paste(cc, caseid, bidx, sep = "_"),

    # outcome ----------------------------------------------------------------
    haz     = hw70 / 100,                          # height-for-age z-score bc from SD
    stunted = factor(haz < -2, levels = c(FALSE, TRUE), labels = c("no", "yes")), # -2 is WHO Cutoff

    # survey weight (rescale within survey later if pooling for estimates)
    wt = v005 / 1e6, # Should we use a weight?

    # child ------------------------------------------------------------------
    age_months  = hw1,
    male        = as.integer(b4 == 1),
    twin        = as.integer(b0 > 0), # Twin/birth order
    first_birth = as.integer(is.na(b11)), # Preceding birth interval
    birth_int   = replace_na(b11, 0),              # 0 for first births (flagged above)
    birth_wt_kg = na_if_ge(m19, 9000) / 1000,      # 9996 = not weighed, 9998 = DK ; converting grams to kg
    size_birth  = na_if_ge(m18, 8),                # 1 very large ... 5 very small

    # mother -----------------------------------------------------------------
    mom_age_birth = (b3 - v011) / 12, # kid birth - mom birth / 12 for year instead of CMC
    mom_height_cm = na_if_ge(v438, 9990) / 10,
    mom_bmi       = na_if_ge(v445, 9990) / 100,
    mom_educ_yrs  = na_if_ge(v133, 97),
    partner_educ  = na_if_ge(v715, 97),            # NA also for no partner
    has_partner   = as.integer(v501 %in% c(1, 2)), # married or living together
    child_deaths  = v206 + v207,

    # household --------------------------------------------------------------
    water_mins = case_when(v115 == 996 ~ 0,        # water on premises
                           v115 >= 997 ~ NA_real_,
                           TRUE ~ as.numeric(v115)),
    # Standard DHS codes; CHECK against each country's labels before trusting.
    improved_water  = as.integer(v113 %in% c(10:14, 20, 21, 30, 31, 40, 41, 51, 61, 62, 71, 91, 92)),
    improved_toilet = as.integer(v116 %in% c(10:13, 15, 20:22, 41)),
    shared_toilet   = as.integer(v160 == 1),
    clean_fuel      = as.integer(v161 %in% 1:4),   # electricity, LPG, gas, biogas
    electricity     = as.integer(v119 == 1),
    radio           = as.integer(v120 == 1),
    tv              = as.integer(v121 == 1),
    fridge          = as.integer(v122 == 1),
    finished_floor  = as.integer(v127 >= 30 & v127 < 96),
    urban           = as.integer(v025 == 1),
    hh_size         = v136,
    n_under5        = v137,
    female_head     = as.integer(v151 == 2),
    head_age        = na_if_ge(v152, 97),
    owns_land       = as.integer(v745b %in% 1:3),
    distance_problem = as.integer(v467d == 1),
    insured         = as.integer(v481 == 1)
  ) |>
  # wealth score is built separately per country, so standardize within survey
  group_by(cc) |>
  mutate(wealth_z = as.numeric(scale(v191))) |>
  ungroup()

# Quick check: missingness of key predictors by survey
kids |>
  group_by(cc) |>
  summarise(n = n(),
            across(c(mom_height_cm, birth_wt_kg, partner_educ),
                   ~ round(mean(is.na(.x)), 2))) |>
  print(n = Inf)


# -----------------------------------------------------------------------------
# 6. GPS: read all cluster shapefiles into one table
# -----------------------------------------------------------------------------
shp_files <- list.files("dhs_gps_unzipped", pattern = "\\.shp$",
                        full.names = TRUE, ignore.case = TRUE)

gps <- map(shp_files, \(f) st_read(f, quiet = TRUE) |>
             select(DHSCC, DHSCLUST, URBAN_RURA, LATNUM, LONGNUM, ALT_DEM)) |>
  do.call(what = rbind) |>                         # stack into one sf table
  filter(!(LATNUM == 0 & LONGNUM == 0)) |>         # 0,0 means location missing
  mutate(cluster_id = paste(DHSCC, DHSCLUST, sep = "_")) |>
  filter(cluster_id %in% kids$cluster_id)          # only surveys we use

# ALT_DEM = elevation (m) from a global elevation model: replaces v040.

# -----------------------------------------------------------------------------
# 7. SPEI drought: monthly value at every cluster
# -----------------------------------------------------------------------------
spei <- rast("data/spei01.nc", subds = "spei")     # monthly, 0.5 deg, 1901-2024
spei <- spei[[time(spei) >= as.Date("2005-01-01")]] # covers all children's windows
spei <- crop(spei, ext(-20, 55, -36, 28))           # Sub-Saharan Africa box

spei_pts <- terra::extract(spei, vect(gps), ID = FALSE)
names(spei_pts) <- format(time(spei), "%Y-%m")

spei_long <- spei_pts |>
  mutate(cluster_id = gps$cluster_id) |>
  pivot_longer(-cluster_id, names_to = "ym", values_to = "spei") |>
  mutate(cmc = (as.integer(substr(ym, 1, 4)) - 1900) * 12 +
               as.integer(substr(ym, 6, 7))) |>    # DHS "century month code"
  select(cluster_id, cmc, spei)


# -----------------------------------------------------------------------------
# 8. Child-specific drought exposure windows
# -----------------------------------------------------------------------------
# b3 = birth month (CMC), v008 = interview month (CMC)
windows <- kids |>
  select(child_id, cluster_id, b3, v008) |>
  mutate(
    utero_start = b3 - 9,  utero_end = b3 - 1,     # 9 months before birth
    yr1_start   = b3,      yr1_end   = b3 + 11,    # first year of life
    yr2_start   = b3 + 12, yr2_end   = b3 + 23,    # second year of life
    rec_start   = v008 - 12, rec_end = v008 - 1    # 12 months before interview
  ) |>
  pivot_longer(ends_with(c("_start", "_end")),
               names_to = c("window", ".value"), names_sep = "_") |>
  mutate(end = pmin(end, v008 - 1))                # never after the interview

exposure <- windows |>
  filter(start <= end) |>                          # e.g. no yr2 for babies < 12 mo
  inner_join(spei_long,
             join_by(cluster_id, start <= cmc, end >= cmc)) |>
  group_by(child_id, window) |>
  summarise(
    spei_mean     = mean(spei, na.rm = TRUE),
    drought_share = mean(spei < -1, na.rm = TRUE), # share of months in drought
    n_months      = sum(!is.na(spei)),             # < window length if SPEI ran out
    .groups = "drop"
  ) |>
  pivot_wider(names_from = window,
              values_from = c(spei_mean, drought_share, n_months))


# -----------------------------------------------------------------------------
# 9. MapSPAM cropland around each cluster
# -----------------------------------------------------------------------------
# Harvested area (ha) per 5-arc-minute cell (~9 km), 2020 snapshot.
# H_TA = all technologies, H_TR = rainfed only.
spam_dir <- "data/dataverse_files(1)/Global_CSV/spam2020V2r2_global_harvested_area"

read_spam <- function(file) {
  read_csv(file.path(spam_dir, file), show_col_types = FALSE) |>
    filter(between(x, -20, 55), between(y, -36, 28)) |>   # SSA box: much smaller
    mutate(
      crop_ha   = rowSums(across(whea:rubb)),              # all crops
      staple_ha = rowSums(across(c(maiz, sorg, mill, pmil, rice, whea,
                                   cass, yams, swpo, pota, bean)))
    ) |>
    select(x, y, crop_ha, staple_ha)
}

spam_all <- read_spam("spam2020V2r2_global_H_TA.csv")
spam_rf  <- read_spam("spam2020V2r2_global_H_TR.csv") |>
  rename(rainfed_ha = crop_ha) |> select(x, y, rainfed_ha)

spam_joined <- left_join(spam_all, spam_rf, by = c("x", "y"))

tmpl <- rast(ext(-20, 55, -36, 28), resolution = 1/12, crs = "EPSG:4326", vals = 0)
spam_cells <- cellFromXY(tmpl, as.matrix(spam_joined[, c("x", "y")]))

to_rast <- function(var) {
  r <- tmpl
  r[spam_cells] <- replace_na(spam_joined[[var]], 0)
  names(r) <- var
  r
}

spam_r <- c(to_rast("crop_ha"), to_rast("staple_ha"), to_rast("rainfed_ha"))

# 10 km buffer: larger than the GPS displacement (2 km urban / 5 km rural) and about one MapSPAM cell, so it captures the farmland around a village.
gps_buf <- st_buffer(gps, dist = 10000)

spam_clusters <- terra::extract(spam_r, vect(gps_buf), fun = mean,
                                na.rm = TRUE, ID = FALSE) |>
  mutate(cluster_id   = gps$cluster_id,
         rainfed_share = rainfed_ha / crop_ha) |>
  rename(crop_ha_mean = crop_ha, staple_ha_mean = staple_ha)


# -----------------------------------------------------------------------------
# 10. Merge everything and save
# -----------------------------------------------------------------------------
kids_merged <- kids |>
  inner_join(st_drop_geometry(gps), by = "cluster_id") |>  # drops kids w/o GPS
  left_join(exposure,      by = "child_id") |>
  left_join(spam_clusters, by = "cluster_id")

# sanity checks
nrow(kids); nrow(kids_merged)            # how many children lost GPS
count(kids_merged, cc)                   # children per survey
summary(select(kids_merged, starts_with("spei_mean"), crop_ha_mean))

dir.create("data/analysis", showWarnings = FALSE, recursive = TRUE)
write_rds(kids_merged, "data/analysis/kids_merged.rds")


