#!/usr/bin/env python
# pyspark2 --master yarn --num-executors 5 --executor-memory 10g --executor-cores 2

## for running the shell script ja_dataEx_request.sh from the dataEx_Shiny directory
# bash ja_dataEx_request.sh --email abc@xyz.com --customerID 123456789 --start 20190401 --end 20190430 --dataset userplustime

#######################################################
######## importing packages ##########
import argparse
import datetime as dt
import sys
import pandas as pd
import numpy as np
import subprocess
import re

try:
    from pyspark import SparkConf, SparkContext, SQLContext
    from pyspark.sql import HiveContext
    from pyspark.sql.functions import col
    from pyspark.sql.types import StructField, StructType #for StructField and StructType
    from pyspark.sql.types import * #for LongType() etc
    # from pyspark.sql.functions import *
except:
    print("Spark libs not found")

#######################################################
######## generating the queries ##########

# standard inputs
#email = "abc@xyz.com"
#customerID = 123456789
#start = "20181101"
#end = "20190221"
#dataset = 'userplustime'

# reading job args
parser = argparse.ArgumentParser()
parser.add_argument('--email', type=str)
parser.add_argument('--customerID')
parser.add_argument('--start')
parser.add_argument('--end')
parser.add_argument('--dataset')
args = parser.parse_args()

email = args.email
customerID = args.customerID
start = args.start
end = args.end
dataset = args.dataset
print("Arguments received.")

conf = SparkConf().setMaster("local")
sc = SparkContext(conf=conf)
sqlContext = HiveContext(sc)
print("HiveContext created as sqlContext")

# converting dates into correct format
startdate = pd.Timestamp(str(start)) #incase start is a number
enddate = pd.Timestamp(str(end)) #incase start is a number
diff = enddate - startdate

#making a list of dates between start and end, and the respective queries
dates = [startdate + pd.Timedelta(days=x) for x in np.arange(diff.days+1)]
queries = ["SELECT * from database.hivetable WHERE customerID="+str(customerID)+" AND year="+str(x.year)+" AND month=" +(str(x.month).zfill(2))+" AND day="+(str(x.day).zfill(2))+";" for x in dates]

#######################################################
######## creating temp parquets, one per day of data ##########

# viewing the schema from the hive table
#dfs = sqlContext.sql('SELECT * FROM database.hivetable LIMIT 0')
#dfs.printSchema()

for i in np.arange(len(queries)):
    query = queries[i][:-1] #removing the semi colon
    filename = query[-29:-25]+query[-14:-12]+query[-3:] #yyyymmdd
    print('Running Query: ' + query)
    df = sqlContext.sql(query)
    print('Saving Query Result to '+'/hdfs/' + dataset + 'datatemp/'+filename) #filename is the date
    df.write.save(path='/hdfs/'+dataset+'datatemp/'+filename, format='parquet',mode='error')

#####################################################
# creating a list of which files are present in the directory

# creating the command then running it

def run_cmd(args_list):
        """
        run linux commands
        """
        # import subprocess
        print('Running system command: {0}'.format(' '.join(args_list)))
        proc = subprocess.Popen(args_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        s_output, s_err = proc.communicate()
        s_return =  proc.returncode
        return s_return, s_output, s_err 

cmd = ('hdfs dfs -ls /hdfs/'+dataset+'datatemp').split() # cmd must be an array of arguments
(ret, out, err)= run_cmd(cmd)

# removing first and last lines which are 'Found x items' and ''
lines = str(out).split('\\n')[1:-1] 

# splitting the lines to extract the path name
paths = list(np.arange(len(lines)))
for i in np.arange(len(lines)):
    paths[i] = re.split('\d{2}:\d{2}\s', lines[i])[1] # splitting on the time (e.g. 12:45) and taking the element AFTER the split

#######################################################
######## appending the temp parquets together ##########

# this worked ok even though I got "Exception in connection" errors
no_rows = 0
for i in np.arange(len(paths)):
    path = paths[i]
    cmd = ('hdfs dfs -ls ' + path).split() # cmd must be an array of arguments
    (ret, out, err)= run_cmd(cmd)
    firstpart = str(out).split('\\n')[2] #extracting first part name
    if 'part' in firstpart: 
        df = sqlContext.read.format('parquet').load(path)
        print('Appending dataset: ' + re.search('\w+/\d{8}$',path)[0])
        df.write.save(path='/hdfs/'+dataset+'datatempmerged', format='parquet',mode='append')
        no_rows += df.count()
    else:
        print('No data records found in ' + re.search('\w+/\d{8}$',path)[0])
        no_rows += 0

if no_rows >0 :
    # repartitioning all the joining temp files into 1
    sqlContext.read.format('parquet').load('/hdfs/'+dataset+'datatempmerged').repartition(1).write.save(path='/hdfs/'+dataset, format = 'parquet')
    df = sqlContext.read.format('parquet').load('/hdfs/'+dataset)
    print('Successfully appended '+ str(df.count()) +' rows together')


#######################################################
######## cleaning up the hdfs ##########
# removing 'per day' parquets
cmd = ('hdfs dfs -rmr /hdfs/'+dataset+'datatemp').split() # cmd must be an array of arguments
(ret, out, err)= run_cmd(cmd)
# note this sends files to trash. output can be seen in "out"

# removing merged 'per day' parquets
if no_rows >0 :
    cmd = ('hdfs dfs -rmr /hdfs/'+dataset+'datatempmerged').split() # cmd must be an array of arguments
    (ret, out, err)= run_cmd(cmd)
    # note this sends files to trash. output can be seen in "out"


########################################################
######### sending the confirmation email ###############

startdatewords = (str(startdate.day).zfill(2))+'/'+(str(startdate.month).zfill(2))+'/'+str(startdate.year)
enddatewords = (str(enddate.day).zfill(2))+'/'+(str(enddate.month).zfill(2))+'/'+str(enddate.year)

# writing the email

with open('temp_'+dataset+'_email.txt','w') as f:
    if no_rows >0 :
        f.write('You requested data for the customer '+str(customerID)+' for the timeperiod  '+startdatewords+' - '+enddatewords+'. \n\nThese data are now available and can be viewed through the dataEx app using the Dataset-ID '+dataset+'. \n\nIn the case of problems, please contact X. \n\nThank you.')
    else:
        f.write('You requested data for the customer '+str(customerID)+' for the timeperiod  '+startdatewords+' - '+enddatewords+'. \n\nNo available data were found for this time period. If the data requested were over 6 months old, they have likely been deleted due to GDPR reasons. \n\nIn the case of problems, please contact X. \n\nThank you.')
    
# writing a function to handle running piped commands on commandline
def run_cmd2(args_list_of_lists):
        """
        run linux commands
        """
        # import subprocess
        proc1 = subprocess.Popen(args_list_of_lists[0], stdout=subprocess.PIPE)
        proc2 = subprocess.Popen(args_list_of_lists[1], stdin=proc1.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        s_output, s_err = proc2.communicate()
        s_return =  proc2.returncode
        return s_return, s_output, s_err

# sending the email
if no_rows >0 :
    cmd2 = [['cat','temp_'+user+'_email.txt'],['mailx','-s','"Your report is ready!"',email]]
else:
    cmd2 = [['cat','temp_'+user+'_email.txt'],['mailx','-s','"Data request: No data found"',email]]
run_cmd2(cmd2)

# removing the text for the email
run_cmd(['rm','temp_'+user+'_email.txt'])

