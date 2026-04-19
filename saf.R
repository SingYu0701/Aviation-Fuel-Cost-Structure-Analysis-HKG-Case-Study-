# =========================
# 0. Libraries
# =========================
library(tidyverse)
library(lubridate)
library(geosphere)
library(scales)
library(readxl)
library(purrr)
library(tidyquant)

options(scipen = 999)
set.seed(42)

# =========================
# 1. Load Data
# =========================
hkg_clean <- read_excel("hkg.xlsx") %>%
  transmute(
    year = Year,
    flights = AircraftTotal,
    pax = PassengerTotal
  ) %>%
  filter(year >= 2010, year <= 2024) %>%
  mutate(
    flights_k = flights / 1000,
    pax_m = pax / 1e6
  )

# =========================
# 2. Oil price
# =========================
oil_xts <- getSymbols("DCOILWTICO", src="FRED", auto.assign=FALSE)

oil_clean <- tibble(
  date = index(oil_xts),
  oil_price = as.numeric(oil_xts)
) %>%
  mutate(year = year(date)) %>%
  group_by(year) %>%
  summarise(oil_price = mean(oil_price, na.rm=TRUE), .groups="drop")

# =========================
# 3. Carbon price
# =========================
carbon_yearly <- read_csv("pricedata.csv", show_col_types = FALSE) %>%
  mutate(
    date = mdy(Date),
    year = year(date),
    carbon_price = as.numeric(gsub(",", "", Price))
  ) %>%
  group_by(year) %>%
  summarise(carbon_price = mean(carbon_price, na.rm=TRUE), .groups="drop")

# =========================
# 4. Distance
# =========================
routes <- read.csv("routes.dat", header = FALSE)
airports <- read.csv("airports.dat", header = FALSE)

colnames(routes) <- c("Airline","AirlineID","Source","SourceID",
                      "Destination","DestID","Codeshare","Stops","Equipment")

colnames(airports) <- c("AirportID","Name","City","Country",
                        "IATA","ICAO","Lat","Lon",
                        "Altitude","Timezone","DST",
                        "Tz","Type","Source")

hkg_coord <- airports %>% filter(IATA=="HKG")

hkg_routes <- routes %>%
  filter(Source=="HKG") %>%
  count(Destination, name="freq") %>%
  left_join(airports, by=c("Destination"="IATA")) %>%
  filter(!is.na(Lat)) %>%
  mutate(
    distance_km = distHaversine(
      matrix(c(hkg_coord$Lon, hkg_coord$Lat), ncol=2),
      matrix(c(Lon, Lat), ncol=2)
    ) / 1000
  )

avg_distance <- weighted.mean(hkg_routes$distance_km, hkg_routes$freq)

# =========================
# 5. Merge
# =========================
df <- hkg_clean %>%
  left_join(oil_clean, by="year") %>%
  left_join(carbon_yearly, by="year") %>%
  drop_na()

# =========================
# 6. Aviation system
# =========================
df <- df %>%
  mutate(
    
    covid_factor = case_when(
      year == 2020 ~ 0.25,
      year == 2021 ~ 0.45,
      year == 2022 ~ 0.75,
      TRUE ~ 1
    ),
    
    load_factor = 0.82 * covid_factor,
    
    # -------------------------
    # COVID also reduces efficiency
    # -------------------------
    fuel_intensity = 0.03 * (1 + 0.1*(1 - covid_factor)),
    
    ASK = flights_k * 1000 * avg_distance * 160 * load_factor,
    
    total_fuel = ASK * fuel_intensity,
    
    emission = total_fuel * 3.16 / 1000
  )
df <- df %>%
  mutate(
    saf_share = 1 / (1 + exp(-0.4 * (year - 2028))),
    
    saf_fuel = total_fuel * saf_share,
    jet_fuel = total_fuel * (1 - saf_share),
    
    emission_jet = jet_fuel * 3.16 / 1000,
    emission_saf = saf_fuel * 0.25 / 1000,   
    
    emission_total = emission_jet + emission_saf
  )
# =========================
# 7. Cost model
# =========================
cost_model <- function(fuel, oil, carbon, emission, year, ASK, saf_override = NULL){
  
  oil <- pmax(oil, 1)
  carbon <- pmax(carbon, 0)
  
  fuel_price <- oil / 127
  
  base_saf <- ifelse(year < 2022, 0,
                     1 / (1 + exp(-0.4 * (year - 2028))))
  
  saf_share <- if(!is.null(saf_override)){
    pmax(0, pmin(0.4, saf_override))
  } else {
    base_saf
  }
  
  saf_price <- fuel_price * (1.4 - 0.01*(year - 2025))
  saf_price <- pmax(saf_price, 1.1 * fuel_price)
  
  saf_fuel <- fuel * saf_share
  jet_fuel <- fuel * (1 - saf_share)
  
  fuel_cost <- jet_fuel * fuel_price * 0.8
  saf_cost  <- saf_fuel * saf_price
  carbon_cost <- emission * carbon
  
  non_fuel_cost <- ASK * 0.06
  
  tibble(
    fuel_cost,
    saf_cost,
    carbon_cost,
    total_cost = fuel_cost + saf_cost + carbon_cost + non_fuel_cost
  )
}
df <- bind_cols(
  df,
  cost_model(
    df$total_fuel,
    df$oil_price,
    df$carbon_price,
    df$emission,
    df$year,
    df$ASK
  )
)

# =========================
# 8. KPI
# =========================
df <- df %>%
  mutate(
    cost_scale = 0.9,
    revenue_scale = 0.8,
    
    base_yield = 0.12,
    markup = 1.2,
    
    price_trend = 1 + 0.015*(year - 2010),
    demand_shock = rnorm(n(), 0, 0.02),
    
    ticket_price = base_yield * markup *
      price_trend * (1 + demand_shock),
    
    ticket_price = ticket_price * 0.6,
    
    revenue = ASK * ticket_price,
    
    CASK = (total_cost * cost_scale) / ASK,
    RASK = (revenue * revenue_scale) / ASK,
    
    margin = RASK - CASK
  )
# =========================
# 9. Plots
# =========================

df %>%
  select(year, fuel_cost, saf_cost, carbon_cost) %>%
  mutate(total = fuel_cost + saf_cost + carbon_cost) %>%
  mutate(
    fuel_share = fuel_cost / total,
    saf_share = saf_cost / total,
    carbon_share = carbon_cost / total
  ) %>%
  select(year, fuel_share, saf_share, carbon_share) %>%
  pivot_longer(-year) %>%
  ggplot(aes(year, value, fill=name)) +
  geom_area() +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal() +
  labs(
    title = "Airline Cost Structure (Share of Total Cost)",
    x = "Year",
    y = "Share",
    fill = "Component"
  )
# CASK vs RASK
ggplot(df, aes(year)) +
  geom_line(aes(y=CASK, color="CASK"), size=1.2) +
  geom_line(aes(y=RASK, color="RASK"), size=1.2) +
  theme_minimal() +
  labs(title="CASK vs RASK", y="USD/ASK")
ggplot(df, aes(year, margin)) +
  geom_line(color = "darkgreen", size = 1.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  labs(
    title = "Operating Margin (RASK - CASK)",
    y = "USD per ASK"
  )
# =========================
# 10. Scenario
# =========================

future <- expand_grid(
  year = 2025:2035,
  scenario = c("baseline","high_oil","high_carbon","SAF")
) %>%
  mutate(
    
    # -------------------------
    # shock drivers
    # -------------------------
    oil_price = mean(df$oil_price),
    carbon_price = mean(df$carbon_price),
    
    oil_price = ifelse(scenario=="high_oil", oil_price*2, oil_price),
    carbon_price = ifelse(scenario=="high_carbon", carbon_price*1.5, carbon_price),
    
    saf_policy = ifelse(scenario=="SAF", 0.6, 0.2),
    
    # -------------------------
    # supply side
    # -------------------------
    recovery = case_when(
      year == 2025 ~ 0.95,
      year == 2026 ~ 1.00,
      TRUE ~ 1.02
    ),
    
    ASK = mean(df$ASK) * exp(0.02*(year-2024)) * recovery,
    
    fuel = ASK * 0.03,
    saf_share = ifelse(scenario == "SAF", 0.6, 0.2),
    saf_fuel = fuel * saf_share,
    jet_fuel = fuel * (1 - saf_share),
    emission = jet_fuel * 3.16/1000 + saf_fuel * 0.25/1000,
  )

future <- bind_cols(
  future,
  cost_model(
    future$fuel,
    future$oil_price,
    future$carbon_price,
    future$emission,
    future$year,
    future$saf_policy
  )
)

future <- future %>%
  mutate(
    
    # -------------------------
    # demand system base indices (先算！)
    # -------------------------
    fuel_index = oil_price / mean(df$oil_price),
    carbon_index = carbon_price / mean(df$carbon_price),
    
    # -------------------------
    # SAF structure
    # -------------------------
    saf_policy = ifelse(scenario == "SAF", 0.6, 0.2),
    
    saf_share = saf_policy,
    
    # -------------------------
    # transition effects
    # -------------------------
    transition_penalty = (1 - saf_policy)^2 * 0.15,
    
    carbon_risk_premium = carbon_index * (1 - saf_policy) * 0.08,
    
    esg_factor = exp(-0.3 * (1 - saf_policy)),
    
    # -------------------------
    # demand system
    # -------------------------
    scenario_factor = case_when(
      scenario == "baseline" ~ 0.8,
      scenario == "high_oil" ~ 0.92,
      scenario == "high_carbon" ~ 0.93,
      scenario == "SAF" ~ 0.95
    ),
    
    demand_factor =
      exp(-0.35*(fuel_index - 1)) *
      exp(-0.25*(carbon_index - 1)) *
      exp(-0.1*(saf_policy - 0.2)) *
      scenario_factor *
      (1 + 0.05 * saf_policy),
    
    # -------------------------
    # pricing system
    # -------------------------
    pass_through = 0.6,
    
    ticket_price = (total_cost / ASK) * pass_through,
    ticket_price = pmin(pmax(ticket_price, 0.05), 0.25),
    
    # -------------------------
    # profit
    # -------------------------
    profit =
      ASK * ticket_price * demand_factor * esg_factor -
      total_cost * (1 + transition_penalty + carbon_risk_premium)
  )
future <- bind_cols(future,
                    cost_model(
                      future$fuel,
                      future$oil_price,
                      future$carbon_price,
                      future$emission,
                      future$year,
                      future$saf_policy  
                    )
)


# Scenario plot
ggplot(future, aes(year, profit, color = scenario)) +
  geom_line(size = 1.2) +
  scale_y_continuous(labels = comma) +
  scale_x_continuous(breaks = seq(2025, 2035, by = 2)) +
  theme_minimal() +
  labs(title = "Profit Scenario Analysis")

# =========================
# 11. Monte Carlo
# =========================
mc <- map_df(1:1000, function(i){
  
  oil_path <- cumprod(1 + rnorm(11,0.02,0.08)) * tail(df$oil_price,1)
  
  ASK <- mean(df$ASK)*exp(0.02*(1:11))
  
  fuel <- ASK*0.03
  saf_share = 0.6
  saf_fuel = fuel * saf_share
  jet_fuel = fuel * (1 - saf_share)
  emission = jet_fuel * 3.16/1000 + saf_fuel * 0.25/1000
  
  cost <- cost_model(
    fuel,
    oil_path,
    mean(df$carbon_price),
    emission,
    2025:2035,
    ASK   
  )
  
  revenue <- ASK * 0.11 * exp(-0.1*(oil_path/mean(oil_path)-1))
  profit <- revenue - cost$total_cost
  
  tibble(profit_2035 = profit[11])
})

# VaR
quantile(mc$profit_2035, c(0.05,0.5,0.95))

# Plot
ggplot(mc, aes(profit_2035)) +
  geom_histogram(bins=40, fill="steelblue", alpha=0.6) +
  geom_vline(xintercept=quantile(mc$profit_2035,0.05), color="red") +
  geom_vline(xintercept=quantile(mc$profit_2035,0.95), color="red") +
  scale_x_continuous(labels=comma) +
  theme_minimal() +
  labs(title="Profit Risk Distribution (2035)")

hkg_routes %>%
  mutate(
    emission = distance_km * freq,
    emission_group = ntile(emission, 3),
    emission_group = factor(emission_group,
                            levels = c(1, 2, 3),
                            labels = c("Low", "Medium", "High"))
  ) %>%
  ggplot(aes(distance_km, emission, color = emission_group)) +
  geom_point(alpha = 0.8) +
  
  geom_smooth(
    method = "lm",
    se = TRUE,
    color = "red",
    fill = "grey70",
    alpha = 0.3,
    linewidth = 1
  ) +
  
  theme_minimal(base_size = 13) +
  labs(
    title = "Route Emission Intensity (Distance vs Traffic)",
    color = "Emission Level"
  )+ 
  annotate("text",
              x = quantile(hkg_routes$distance_km, 0.4),
              y = max(hkg_routes$distance_km * hkg_routes$freq),
              label = paste0("Corr = ",
                             round(cor(hkg_routes$distance_km,
                                       hkg_routes$distance_km * hkg_routes$freq), 3)),
              hjust = 1)

ggplot(df, aes(year)) +
  geom_line(aes(y = saf_share * max(emission_total), color = "SAF share"), size = 1.2) +
  geom_line(aes(y = emission_total, color = "CO2 emission"), size = 1.2) +
  scale_y_continuous(
    labels = comma
  ) +
  theme_minimal() +
  labs(
    title = "SAF Adoption vs CO2 Emission",
    y = "Scaled Value",
    color = "Indicator"
  )

