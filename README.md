# Aviation-Fuel-Cost-Structure-Analysis-HKG-Case-Study-

**Personal Data Analysis Project, Apr 2026** 
![Made with R](https://img.shields.io/badge/Made%20with-R-276DC3?logo=r&logoColor=white)

This project is intended for:
- Airline cost structure analysis
- Fuel exposure assessment
- Scenario stress testing
- Aviation economics research support
  
## 1. Overview
This project builds a simplified aviation economics system for Hong Kong (HKG), focusing on:
- **Cost structure decomposition** (fuel / SAF / carbon)
- **Unit economics (CASK / RASK)**
- **Emissions estimation**
- **SAF adoption dynamics**
- Scenario-based **profit simulation**
- Monte Carlo **risk analysis**

## 2. Data
- **Aviation operations**

   hkg.xlsx (2010–2024)
  
  from Hong Kong International Airport – International Civil Aviation Passenger and Cargo Statistics (1998–Present)
  - Aircraft movements
  - Passenger volume
  - Energy prices
- **WTI crude oil (FRED)**
- **Carbon price** dataset (pricedata.csv)

  from EU ETS Carbon Allowance Futures (EUAs) historical market prices
- **Network proxy**
- **OpenFlights (routes.dat, airports.dat)**

  used for average route distance estimation

## 3. Variable definition
### 3.1 ASK (Capacity)

$$ASK=Flights×1000×Avg Distance×160×Load Factor$$

**ASK (Available Seat Kilometers)** is the core capacity metric of the system.

It converts raw flight activity into transport capacity, taking into account:
- flight volume (Flights)
- network structure (Avg Distance)
- aircraft capacity assumption (Assume 160 seats)
- utilization efficiency (Load Factor)

ASK represents:
- total revenue-generating capacity
- fuel exposure base
- emission scaling base

### 3.2 Fuel & Emissions

$$Fuel=ASK×Fuel Intensity$$

$$CO_2=Fuel×3.16/1000$$

**Fuel consumption is assumed to scale linearly with ASK.**

Emission conversion uses standard aviation emission factor:
**3.16 kg CO₂ per kg jet fuel**

This module defines:
- fuel exposure (cost driver)
- emissions exposure (carbon cost driver)
  
### 3.3 SAF adoption
$$saf_{share} = 1 / (1 + exp(-0.4 * (year - 2028)))$$

SAF adoption is modeled as a **logistic diffusion process**:
- **slow early adoption** (pre-2025)
- **inflection around 2028**
- **accelerated adoption post-2030**

SAF affects:
- fuel substitution (jet → SAF)
- emission reduction
- cost structure shift

**SAF is a structural transition variable, not a short-term cost lever**

<img width="1662" height="953" alt="圖片" src="https://github.com/user-attachments/assets/4e86dfcc-e9f4-4b96-9e53-a2a6fa2421ee" />
This figure compares SAF penetration with total emissions over time.

- **SAF share increases structurally after 2022**
- CO₂ emissions **decline gradually but not linearly due to Covid 19**.


## 4. Cost model

$$Total Cost=Fuel Cost+SAF Cost+Carbon Cost+Non-Fuel Cost$$

The airline cost structure is decomposed into four components:

(1) Fuel Cost

Driven by **oil price × jet fuel** consumption

(2) SAF Cost

  **SAF replaces jet fuel partially, but at higher unit cost**
  
(3) Carbon Cost

**Emissions × carbon price** (regulatory exposure)

(4) Non-fuel Cost

**Fixed / semi-fixed operational cost** (ground handling, labor, etc.)


<img width="1662" height="953" alt="圖片" src="https://github.com/user-attachments/assets/642fc55a-eed3-4100-a3d7-1741d1900abe" />

Cost Structure Over Time (decomposition of total airline cost only for fuel)

- **fuel is dominant** cost driver

- carbon cost **increases structurally post-2015**

- SAF shifts composition but **raises short-term** cost base

## 5. Unit economics

$$CASK=Total Cost/ASK$$
$$RASK=Revenue/ASK$$

- CASK = unit cost per capacity
- RASK = unit revenue per capacity

This defines airline profitability at unit level:
- if **RASK > CASK → profitable**
- if **CASK increases faster → margin compression**

This is the core KPI structure of airline finance
​
<img width="1662" height="953" alt="圖片" src="https://github.com/user-attachments/assets/f8715028-e1d7-4f75-8eb2-77ee659e57f0" />
unit cost vs unit revenue over time
- margin compression driven by fuel shocks
- **revenue is more stable than cost**
- profitability is **cost-driven**, not demand-driven
  
<img width="1072" height="512" alt="圖片" src="https://github.com/user-attachments/assets/21fdaed8-84ae-4fd8-ae07-b02bf5166ad2" />
Operating Margin
Definition:**RASK − CASK**

- margin volatility is **fuel-driven**
- structural **recovery** appears post-shock periods

### 6. Scenarios

The model evaluates 4 macro environments:
- Baseline
- High oil price
- High carbon price
- SAF policy shock

Each scenario generates:

(1) Profit trajectory (2025–2035)

→ **long-term financial performance under macro regimes**

(2) Cost structure shift

→ **how fuel / carbon / SAF composition evolves**

(3) Demand response

→ **how pricing and cost shocks affect demand elasticity**


Scenario module answers:
**“What breaks airline profitability under different macro regimes?”**

<img width="1662" height="953" alt="圖片" src="https://github.com/user-attachments/assets/ad68e76a-0594-4037-aa0b-6ead033d755a" />

- oil price dominates short-term outcomes
- **carbon pricing shifts long-term baseline downward**
- **SAF stabilizes long-term and high profit**

### 7. Monte Carlo Simulation
Setup 1,000 simulations stochastic oil price path demand variability

Output metrics

(1) Profit distribution (2035)

→ **long-term uncertainty of profitability**

(2) Downside risk (VaR)

→ **probability of extreme loss scenarios**

This module captures:
- fuel price volatility risk
- tail risk exposure
- non-linear profitability behavior
This is closer to risk management / treasury view
<img width="1662" height="953" alt="圖片" src="https://github.com/user-attachments/assets/536f4783-f6c9-49ae-b57e-f20977db400e" />
distribution of profit outcomes (2035)
- asymmetric risk profile
- downside risk driven by fuel spikes
- mean outcome is not representative

## 8. Route Emission Intensity (Distance vs Traffic)

<img width="1662" height="953" alt="圖片" src="https://github.com/user-attachments/assets/f895f2f6-06f0-4c42-a2d6-3f4882206682" />

This chart shows the relationship between route **distance and traffic volume-weighted emission exposure**.
- X-axis: route distance (km)
- Y-axis: traffic-weighted emission proxy
- Color: emission intensity groups (Low / Medium / High)

A linear trend line is fitted to evaluate whether **long-haul routes disproportionately contribute to emission intensity**, correlation with 0.742.

## 9. Key Outputs
- Cost structure decomposition
- SAF transition impact on cost base
- Carbon cost exposure over time
- Unit economics (CASK / RASK)
- Profit sensitivity to macro shocks
- Risk distribution of long-term profitability

## 10. Tools
- R (tidyverse, ggplot2, purrr)
- Time series processing (FRED data)
- Scenario modeling
- Monte Carlo simulation
- Geospatial distance calculation (Haversine)

