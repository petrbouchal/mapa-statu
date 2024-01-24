rectangularise_orgdata <- function(orgdata_raw) {
  orgdata_for_rect <- orgdata_raw |> replace_na(list(parent = "God"))

  orgdata_rect <- orgdata_for_rect |>
    filter(parent == "stat") |>
    select(level1_id = id, level1_nazev = nazev) |>
    left_join(orgdata_for_rect |>
                select(level1_id = parent, level2_id = id,
                       level2_nazev = nazev, p2 = mista_prac, s2 = mista_sluz), by = "level1_id") |>
    left_join(orgdata_for_rect |>
                select(level2_id = parent, level3_id = id,
                       level3_nazev = nazev, p3 = mista_prac, s3 = mista_sluz), by = "level2_id") |>
    left_join(orgdata_for_rect |>
                select(level3_id = parent, level4_id = id,
                       level4_nazev = nazev, p4 = mista_prac, s4 = mista_sluz), by = "level3_id") |>
    left_join(orgdata_for_rect |>
                select(level4_id = parent, level5_id = id,
                       level5_nazev = nazev, p5 = mista_prac, s5 = mista_sluz), by = "level4_id") |>
    left_join(orgdata_for_rect |>
                select(level5_id = parent, level6_id = id,
                       level6_nazev = nazev, p6 = mista_prac, s6 = mista_sluz), by = "level5_id") |>

    # take lowest-level non-missing employee counts
    mutate(mista_sluz = coalesce(s6, s5, s4, s3, s2),
           mista_prac = coalesce(p6, p5, p4, p3, p2)) |>
    select(-starts_with("s"), -starts_with("p"))
  return(orgdata_rect)
}
