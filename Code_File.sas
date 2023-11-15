

/* 
Loading the Data and Pre-processing

 The following code block is used craete a new library "gamestud" and import csv file to temporary dataset.

*/
libname cdsdata '/home/u63249036/sasuser.v94/Assignment';
proc import datafile='/home/u63249036/sasuser.v94/Assignment/Weekly Count1.csv'
        out=work.cds_health_data
        dbms=csv
        replace;
    
     getnames=yes;
     guessingrows = max ; 
    
run;

/*
	The following code block is used for drop non essentials columns from dataset and create a main dataset for analysis purpose.
*/



data cdsdata.mortdata(replace=yes);
set work.cds_health_data;
where Jurisdiction ~='United States'; 
drop Suppress--Note ;
drop Type;
run;

/*
	The following code block is used to delete a selective row from main dataset in the event of missing value.
*/

data cdsdata.mortdata;
    set cdsdata.mortdata;
    if cmiss(of _all_) then delete;
run;



/* The following code is used to create a new log transformed variable */

data cdsdata.mortdata;
set cdsdata.mortdata;
log_Num_deaths = log(Num_of_death);
run;


data cdsdata.mortdata;
set cdsdata.mortdata;
log_Avg_Num_deaths = log(Avg_Num_of_Deaths_Time);
run;




/* Descriptive Analysis */

/* Frequency Distribution by Jurisdiction, Casue Group and Casue Subgroup */

PROC FREQ DATA=cdsdata.mortdata;
    TABLE Cause_grp Cause_Subgroup ;
RUN;



/* Chart of Frequency Distribution Casue Subgroup */

TITLE 'Number of Death as Per Cause Group and Cause Subgroup';
PROC GCHART DATA=cdsdata.mortdata;
 HBar Cause_grp / sumvar = Num_of_death subgroup = Cause_Subgroup;
RUN;
quit;



/*
The following code block is used to display table structure of main dataset 
and display first 10 records from the dataset.
*/


Proc contents data= cdsdata.mortdata ORDER=varnum;
run;


proc print data=cdsdata.mortdata(obs=10);
run;



/*
Make a tabular summary of Number of Death by Cause Group
*/

proc tabulate data=cdsdata.mortdata;
	title1 'Summary Statistics of Number of Deaths';
   title2 'Number of Deaths By Year as per Casue';
	class Cause_grp year;
	var Num_of_death;
    table Cause_grp* Num_of_death * (N Min Q1 Median Mean Q3 Max StdDev), year;
run;



/*
Histogram log transformed Number of Deaths by Cause Group
*/

ods select Histogram;
proc univariate data=cdsdata.mortdata normal;
	var log_Num_deaths  ;
    class Cause_grp;  
    histogram log_Num_deaths / normal(noprint) kernel;
    inset  mean median std var skewness n / position=ne ;
run;



/* Box plot of Number of deaths log transformed */

proc sgplot data=cdsdata.mortdata;
 vbox log_Num_deaths / category= Cause_grp ;
run;



/* Log Transformed CDF chart of Number of Deaths */

proc univariate data=cdsdata.mortdata noprint;
class Cause_grp;
cdf log_Num_deaths / normal(color=crimson);
inset n mean stddev min max /position=we;
run;



/* Box plot log transformed Num of deaths as per location (52 States including Purto Riceo) */

proc sgplot data= cdsdata.mortdata;
 title 'Number of Deaths in US states (1)';
hbox log_Num_deaths / category=Jurisdiction;
where Jurisdiction in ('Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut'
'Delaware', 'District of Columbia', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana',
'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts');
run;



proc sgplot data= cdsdata.mortdata;
 title 'Number of Deaths in US states (2)';
hbox log_Num_deaths / category=Jurisdiction;
where Jurisdiction in ('Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana',
'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York',
'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania');
run;


proc sgplot data= cdsdata.mortdata;
 title 'Number of Deaths in US states (3)';
hbox log_Num_deaths / category=Jurisdiction;
where Jurisdiction in ('Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee',
'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 
'Wyoming', 'Puerto Rico');
run;




/* Map of USA states */

proc sql ;
    create table mortalitydata as 
    select Jurisdiction_code as state, sum(Num_of_death) as total_death from cdsdata.mortdata
    group by  Jurisdiction_code;
quit;


data cdsdata.mortalitydata(replace=yes);
set work.mortalitydata;
run;


proc gmap data = mortalitydata map=maps.us;
  id state;
  choro total_death;
run;
quit;




/* Weekly Analysis of log Num of Deaths in Specific Year */ 

proc sgplot data=cdsdata.mortdata;
   vline Week / group=Year response=log_Num_deaths    stat=mean markers;
 xaxis display=(nolabel) valuesformat=monyy7.5 fitpolicy=rotate;
 yaxis label="Number of Deaths";
   title 'Number of Deaths by Week';
run;



/* Below is Time series analysis Table and Chart */
/* Line chart of aggregates */


proc sort data=cdsdata.mortdata;
by Week_end_date;
run;

proc sort data=cdsdata.mortdata;
by year Cause_grp;
run;


proc timedata DATA=cdsdata.mortdata out=timeseries outarray=arrays;
by Year Cause_grp;
id Week_end_date interval=month accumulate=total;
var Num_of_death;
run;


/* Create line chart */
proc sgplot data=Work.timeseries;
  title 'Number of Deaths by Cause Group';
  series x=week_end_date y=Num_of_death / group=Cause_grp markers;
  xaxis label='Week Ending Date';
  yaxis label='Number of Deaths';
run;







/* 

PREDICIVE ANALYTICS AND Statistical Analysis

Anova test
*/

proc anova data=cdsdata.mortdata;
class Cause_grp Year;
model log_Num_deaths = Cause_grp Year Cause_grp*Year;
means Cause_grp Year Cause_grp*Year / tukey;
run;





/* Mortality Data (New Table created) 
FOR ARIMA  analysis */

proc sql ;
    create table mortalitydata as 
    select Week_end_date , sum(Num_of_death) as total_death from cdsdata.mortdata
    group by  Week_end_date;
quit;


/* Log transform variable */

data mortalitydata;
set mortalitydata;
log_total_death = log(total_death);
run;



/* Sort the data by date */
proc sort data=Work.mortalitydata;
by Week_end_date;
run;

/* Create a time series variable */
data deaths_ts;
set Work.mortalitydata;
date = intnx('week', Week_end_date, 0, 'b');
format date date9.;
run;

/* Create a time series model */
proc arima data=deaths_ts;
identify var=log_total_death nlag=20;
estimate p=1 q=1;
run;

/* Forecast future values */
proc arima data=deaths_ts;
identify var=log_total_death nlag=20;
estimate p=1 q=1;
forecast lead=20 out=forecast;
run;



/*
END ARIMA Analysis
*/



/*
GLM analysis
*/


proc glm data=deaths_ts;
model log_total_death = date / noint;
run;


 

 







