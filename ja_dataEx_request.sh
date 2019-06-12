#!/bin/bash
spark2-submit --master yarn --num-executors 16 --executor-cores 16 --executor-memory 64G --driver-memory 16G ja_dataEx_dates2parquet_v2.py $@   # Weitergabe der Parameter des run.sh
spark2-submit --master local[1] ja_dataEx_dates2parquet_v2.py $@   # Weitergabe der Parameter des run.sh