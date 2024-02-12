targets::tar_load(orgdata_nodes_processed)

library(stringr)
library(dplyr)
library(tidyr)


urady_skupiny <- orgdata_nodes_processed |>
  drop_na(urad_skupina) |>
  distinct(urad_nazev, urad_skupina)

orgdata_nodes_processed |>
  rows_patch(urady_skupiny) |>
  filter(str_detect(nazev, "[Oo]dd"), urad_skupina == "Ministerstva a ÚV") |>
  mutate(categ_new =
           case_match())
  count(categ == "ostatní")

orgdata_nodes_processed |>
  rows_patch(urady_skupiny) |>
  filter(str_detect(nazev, "[Oo]dd"), urad_skupina == "Ministerstva a ÚV") |>
  filter(categ == "ostatní") |>
  select(nazev, urad_zkratka)
