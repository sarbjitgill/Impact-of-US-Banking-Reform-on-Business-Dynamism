* Create log file with generated output
capture log close
log using T1_output, replace

global path "/Users/Sarb/Documents/Sorbonne/Ca'Foscari/Macroeconomics/Datasets"

*__________________________________________________________
* Data cleaning

* Data import
* Import state-level business dynamics data from .csv file
import delimited using "$path/state-level-data-business-dynamics-1978-2019-BDS.csv", clear // Data at the state-level on business dynamism from 1978 through 2019
browse
describe
destring numberoffirmsfirm numberofestablishmentsestab numberofemployeesemp dhsdenominatordenom numberofestablishmentsbornduring rateofestablishmentsbornduringth numberofestablishmentsexitedduri rateofestablishmentsexitedduring numberofjobscreatedfromexpanding numberofjobscreatedfromopeninges v15 rateofjobscreatedfromopeningesta rateofjobscreatedfromexpandingan numberofjobslostfromcontractinga numberofjobslostfromclosingestab numberofjobslostfromcontractinge rateofjobslostfromclosingestabli rateofjobslostfromcontractingand numberofnetjobscreatedfromexpand rateofnetjobscreatedfromexpandin rateofreallocationduringthelast1 numberoffirmsthatexitedduringthe numberofestablishmentsassociated numberofemployeesassociatedwithf, replace ignore(",") force

* Duplicates Report
duplicates report geographicareanamename yearyear
duplicates drop geographicareanamename yearyear, force // Focus on the aggregate economy only
rename geographicareanamename state
rename yearyear year
rename v15 jobscreatedexpandbizlast12months

* Prepare data on state-level personal income and population for matching

* Used this code below to modify the file but ended up exporting it last minute to carefully separate population and personal income data in excel and reimport (Couldn't find the appropriate Stata command in time to accomplish the objective)
** preserve
** import delimited using "$path/state-level-personal-income-per-capita-and-population-BEA.csv", varnames(5) rowrange(5:107) colrange(2:46) clear
** reshape long year, i(geoname description) j(yearyear)
** rename year value
** rename yearyear year
** sort geoname description year
** browse
** drop _all

* Exported this file manually to carefully separate population and personal income data (Couldn't find the appropriate Stata command in time to accomplish the objective)
* Reimported the revised file
preserve
import delimited using "$path/New file with separate population and income columns.csv", clear 
rename geoname state
sort state year, stable
browse
save "$path/temp.dta", replace
restore
sort state year, stable
browse

* Matching datasets
merge m:1 (state year) using "$path/temp.dta"
tab _merge
drop _merge
erase "$path/temp.dta"

browse

* Matching inflation data to deduce real personal income per capita
preserve
import delimited using "$path/annual-inflation-percent-consumer-prices-for-the-United-States-World-Bank-Data.csv", clear // CPI Annual Inflation Percentage - US - World Bank Data
save "$path/temp.dta", replace
restore
merge m:1 (year) using"$path/temp.dta" // CPI Annual Inflation Percentage - US - World Bank Data
browse
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Generating real personal income per capita variable
generate realpercapitapersonalincome = percapitapersonalincomedollars / (1+(cpiannualinflationpercentageuswo/100))

* Generating reform indicator variable
preserve
import delimited using "$path/Intrastate Deregulation .csv", clear // From JS
save "$path/temp.dta", replace
restore
merge m:1 (state) using"$path/temp.dta"
browse
tab _merge
drop _merge
erase "$path/temp.dta"

generate Di = year>=intrastatederegulationyearma if !missing(intrastatederegulationyearma)
replace Di = 0 if missing(Di)

* Looking at the data by time
tab year

* State fixed effects
egen state_fe = group(state)

* Panel structure
sort state_fe year
xtset state_fe year

* Installing Packages
ssc install reghdfe
ssc install ftools

* Dropping variables in line with Jayaratne and Strahan (1996) before running regressions
drop if state=="Delaware"
drop if year==intrastatederegulationyearma

*__________________________________________________________
* Part I: Fixed-effects regressions

reghdfe rateofestablishmentsbornduringth Di, absorb(state year) cluster(state)
reghdfe rateofestablishmentsbornduringth Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofestablishmentsexitedduring Di, absorb(state year) cluster(state)
reghdfe rateofestablishmentsexitedduring Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofnetjobscreatedfromexpandin Di, absorb(state year) cluster(state)
reghdfe rateofnetjobscreatedfromexpandin Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

* Event study on rateofestablishmentsbornduringth, rateofestablishmentsexitedduring, and rateofjobscreatedfromexpandingan

gen Di5 = (year==(intrastatederegulationyearma+1) | year==(intrastatederegulationyearma+2) | year==(intrastatederegulationyearma+3) | year==(intrastatederegulationyearma+4) | year==(intrastatederegulationyearma+5)) if !missing(intrastatederegulationyearma)
replace Di5 = 0 if missing(Di5)

gen Di10 = (year==(intrastatederegulationyearma+6) | year==(intrastatederegulationyearma+7) | year==(intrastatederegulationyearma+8) | year==(intrastatederegulationyearma+9) | year==(intrastatederegulationyearma+10)) if !missing(intrastatederegulationyearma)
replace Di10 = 0 if missing(Di10)

gen DiLong = year>(intrastatederegulationyearma+10) if !missing(intrastatederegulationyearma)
replace DiLong = 0 if missing(DiLong)

reghdfe rateofestablishmentsbornduringth Di5 Di10 DiLong, absorb(state year) cluster(state)
reghdfe rateofestablishmentsbornduringth Di5 Di10 DiLong realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofestablishmentsexitedduring Di5 Di10 DiLong, absorb(state year) cluster(state)
reghdfe rateofestablishmentsexitedduring Di5 Di10 DiLong realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofnetjobscreatedfromexpandin Di5 Di10 DiLong, absorb(state year) cluster(state)
reghdfe rateofnetjobscreatedfromexpandin Di5 Di10 DiLong realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)


*__________________________________________________________
* Part II: Difference-in-differences regressions

* Import "IBBEA First Deregulation Data"
preserve
import delimited using "$path/IBBEA First Interstate Deregulation.csv", clear
save "$path/temp.dta", replace
restore
merge m:1 (state) using"$path/temp.dta"
browse
drop if state=="Delaware"
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Import "Early Deregulation Index"
preserve
import delimited using "$path/Early Deregulation  Index 2.csv", clear
save "$path/temp.dta", replace
restore
merge m:1 (state year) using "$path/temp.dta"
browse
drop if state=="Delaware"
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Exclude states that introduced deregulations 1 year before and 1 year after 1997 to avoid confounding effects
drop if ibbeafirst==1996 | ibbeafirst==1998

* Treatment indicator
* Generate treatment dummy: deregulation wave was in 1997
gen treated = ibbeafirst==1997

* Focus on the timeframe 1995-1999 to estimate the short-term effect of interstate deregulation and exclude observations out of this timeframe
keep if year>=1996 & year<=1998
tab state if treated==1
tab state if treated==0

* Define the post-deregulation period
gen post=(year>=1997)
sort state post

tab treated post
summ treated
sort state year

* D-i-D regressions
xtreg rateofestablishmentsbornduringth i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofestablishmentsbornduringth i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

xtreg rateofestablishmentsexitedduring i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofestablishmentsexitedduring i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

xtreg rateofnetjobscreatedfromexpandin i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofnetjobscreatedfromexpandin i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

*__________________________________________________________
* BONUS: Finance and Insurance Industry (NAICS 52) x Intrastate Reform Analysis

clear

* Data import
* Import state-level business dynamics data from .csv file
import delimited using "$path/state-level-data-business-dynamics-1978-2019-BDS.csv", clear // Data at the state-level on business dynamism from 1978 through 2019
browse
describe
keep if naicscodenaics=="52"
destring numberoffirmsfirm numberofestablishmentsestab numberofemployeesemp dhsdenominatordenom numberofestablishmentsbornduring rateofestablishmentsbornduringth numberofestablishmentsexitedduri rateofestablishmentsexitedduring numberofjobscreatedfromexpanding numberofjobscreatedfromopeninges v15 rateofjobscreatedfromopeningesta rateofjobscreatedfromexpandingan numberofjobslostfromcontractinga numberofjobslostfromclosingestab numberofjobslostfromcontractinge rateofjobslostfromclosingestabli rateofjobslostfromcontractingand numberofnetjobscreatedfromexpand rateofnetjobscreatedfromexpandin rateofreallocationduringthelast1 numberoffirmsthatexitedduringthe numberofestablishmentsassociated numberofemployeesassociatedwithf, replace ignore(",") force
rename geographicareanamename state
rename yearyear year
rename v15 jobscreatedexpandbizlast12months


* Prepare data on state-level personal income and population for matching
preserve
import delimited using "$path/New file with separate population and income columns.csv", clear 
rename geoname state
sort state year, stable
browse
save "$path/temp.dta", replace
restore
sort state year, stable
browse

* Matching datasets
merge m:1 (state year) using "$path/temp.dta"
tab _merge
drop _merge
erase "$path/temp.dta"

browse

* Matching inflation data to deduce real personal income per capita
preserve
import delimited using "$path/annual-inflation-percent-consumer-prices-for-the-United-States-World-Bank-Data.csv", clear // CPI Annual Inflation Percentage - US - World Bank Data
save "$path/temp.dta", replace
restore
merge m:1 (year) using"$path/temp.dta" // CPI Annual Inflation Percentage - US - World Bank Data
browse
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Generating real personal income per capita variable
generate realpercapitapersonalincome = percapitapersonalincomedollars / (1+(cpiannualinflationpercentageuswo/100))

* Generating reform indicator variable
preserve
import delimited using "$path/Intrastate Deregulation .csv", clear // From JS
save "$path/temp.dta", replace
restore
merge m:1 (state) using"$path/temp.dta"
browse
tab _merge
drop _merge
erase "$path/temp.dta"

generate Di = year>=intrastatederegulationyearma if !missing(intrastatederegulationyearma)
replace Di = 0 if missing(Di)

* Looking at the data by time
tab year

* State fixed effects
egen state_fe = group(state)

* Panel structure
sort state_fe year
xtset state_fe year

* Dropping variables in line with Jayaratne and Strahan (1996) before running regressions
drop if state=="Delaware"
drop if year==intrastatederegulationyearma

* Staggered Fixed-effects Regressions
reghdfe rateofestablishmentsbornduringth Di, absorb(state year) cluster(state)
reghdfe rateofestablishmentsbornduringth Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofestablishmentsexitedduring Di, absorb(state year) cluster(state)
reghdfe rateofestablishmentsexitedduring Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofnetjobscreatedfromexpandin Di, absorb(state year) cluster(state)
reghdfe rateofnetjobscreatedfromexpandin Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

* Difference-in-differences Setup and Regressions
* Import "IBBEA First Deregulation Data"
preserve
import delimited using "$path/IBBEA First Interstate Deregulation.csv", clear
save "$path/temp.dta", replace
restore
merge m:1 (state) using"$path/temp.dta"
browse
drop if state=="Delaware"
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Import "Early Deregulation Index"
preserve
import delimited using "$path/Early Deregulation  Index 2.csv", clear
save "$path/temp.dta", replace
restore
merge m:1 (state year) using "$path/temp.dta"
browse
drop if state=="Delaware"
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Exclude states that introduced deregulations 1 year before and 1 year after 1997 to avoid confounding effects
drop if ibbeafirst==1996 | ibbeafirst==1998

* Treatment indicator
* Generate treatment dummy: deregulation wave was in 1997
gen treated = ibbeafirst==1997

* Focus on the timeframe 1995-1999 to estimate the short-term effect of interstate deregulation and exclude observations out of this timeframe
keep if year>=1996 & year<=1998
tab state if treated==1
tab state if treated==0

* Define the post-deregulation period
gen post=(year>=1997)
sort state post

tab treated post
summ treated
sort state year

* D-i-D regressions
xtreg rateofestablishmentsbornduringth i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofestablishmentsbornduringth i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

xtreg rateofestablishmentsexitedduring i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofestablishmentsexitedduring i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

xtreg rateofnetjobscreatedfromexpandin i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofnetjobscreatedfromexpandin i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

*__________________________________________________________
* BONUS: Manufacturing (NAICS 31-33) Industries x Intrastate Reform Analysis

clear

* Data import
* Import state-level business dynamics data from .csv file
import delimited using "$path/state-level-data-business-dynamics-1978-2019-BDS.csv", clear // Data at the state-level on business dynamism from 1978 through 2019
browse
describe
keep if naicscodenaics=="31-33"
destring numberoffirmsfirm numberofestablishmentsestab numberofemployeesemp dhsdenominatordenom numberofestablishmentsbornduring rateofestablishmentsbornduringth numberofestablishmentsexitedduri rateofestablishmentsexitedduring numberofjobscreatedfromexpanding numberofjobscreatedfromopeninges v15 rateofjobscreatedfromopeningesta rateofjobscreatedfromexpandingan numberofjobslostfromcontractinga numberofjobslostfromclosingestab numberofjobslostfromcontractinge rateofjobslostfromclosingestabli rateofjobslostfromcontractingand numberofnetjobscreatedfromexpand rateofnetjobscreatedfromexpandin rateofreallocationduringthelast1 numberoffirmsthatexitedduringthe numberofestablishmentsassociated numberofemployeesassociatedwithf, replace ignore(",") force
rename geographicareanamename state
rename yearyear year
rename v15 jobscreatedexpandbizlast12months


* Prepare data on state-level personal income and population for matching
preserve
import delimited using "$path/New file with separate population and income columns.csv", clear 
rename geoname state
sort state year, stable
browse
save "$path/temp.dta", replace
restore
sort state year, stable
browse

* Matching datasets
merge m:1 (state year) using "$path/temp.dta"
tab _merge
drop _merge
erase "$path/temp.dta"

browse

* Matching inflation data to deduce real personal income per capita
preserve
import delimited using "$path/annual-inflation-percent-consumer-prices-for-the-United-States-World-Bank-Data.csv", clear // CPI Annual Inflation Percentage - US - World Bank Data
save "$path/temp.dta", replace
restore
merge m:1 (year) using"$path/temp.dta" // CPI Annual Inflation Percentage - US - World Bank Data
browse
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Generating real personal income per capita variable
generate realpercapitapersonalincome = percapitapersonalincomedollars / (1+(cpiannualinflationpercentageuswo/100))

* Generating reform indicator variable
preserve
import delimited using "$path/Intrastate Deregulation .csv", clear // From JS
save "$path/temp.dta", replace
restore
merge m:1 (state) using"$path/temp.dta"
browse
tab _merge
drop _merge
erase "$path/temp.dta"

generate Di = year>=intrastatederegulationyearma if !missing(intrastatederegulationyearma)
replace Di = 0 if missing(Di)

* Looking at the data by time
tab year

* State fixed effects
egen state_fe = group(state)

* Panel structure
sort state_fe year
xtset state_fe year

* Dropping variables in line with Jayaratne and Strahan (1996) before running regressions
drop if state=="Delaware"
drop if year==intrastatederegulationyearma

* Fixed-effects regressions
reghdfe rateofestablishmentsbornduringth Di, absorb(state year) cluster(state)
reghdfe rateofestablishmentsbornduringth Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofestablishmentsexitedduring Di, absorb(state year) cluster(state)
reghdfe rateofestablishmentsexitedduring Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

reghdfe rateofnetjobscreatedfromexpandin Di, absorb(state year) cluster(state)
reghdfe rateofnetjobscreatedfromexpandin Di realpercapitapersonalincome populationpersons, absorb(state year) cluster(state)

* Difference-in-differences Setup and Regressions
* Import "IBBEA First Deregulation Data"
preserve
import delimited using "$path/IBBEA First Interstate Deregulation.csv", clear
save "$path/temp.dta", replace
restore
merge m:1 (state) using"$path/temp.dta"
browse
drop if state=="Delaware"
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Import "Early Deregulation Index"
preserve
import delimited using "$path/Early Deregulation  Index 2.csv", clear
save "$path/temp.dta", replace
restore
merge m:1 (state year) using "$path/temp.dta"
browse
drop if state=="Delaware"
drop _merge
erase "$path/temp.dta"
sort state year, stable

* Exclude states that introduced deregulations 1 year before and 1 year after 1997 to avoid confounding effects
drop if ibbeafirst==1996 | ibbeafirst==1998

* Treatment indicator
* Generate treatment dummy: deregulation wave was in 1997
gen treated = ibbeafirst==1997

* Focus on the timeframe 1995-1999 to estimate the short-term effect of interstate deregulation and exclude observations out of this timeframe
keep if year>=1996 & year<=1998
tab state if treated==1
tab state if treated==0

* Define the post-deregulation period
gen post=(year>=1997)
sort state post

tab treated post
summ treated
sort state year

* D-i-D regressions
xtreg rateofestablishmentsbornduringth i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofestablishmentsbornduringth i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

xtreg rateofestablishmentsexitedduring i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofestablishmentsexitedduring i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

xtreg rateofnetjobscreatedfromexpandin i.post##i.treated earlyderegulationindex, fe cluster(state_fe)
xtreg rateofnetjobscreatedfromexpandin i.post##i.treated earlyderegulationindex realpercapitapersonalincome population, fe cluster(state_fe)

* Close the log and create a .pdf version
log close
translate T1_output.smcl T1_output.pdf
