-- register the JARs required for JSON parsing
REGISTER '/home/arvind/projects/acadgild/project_1.3/lib/*.jar';

-- load the tweets from HDFS using JsonLoader as a Pig map
-- $INPUT_PATH is a property externalized in task.properties
load_tweets = LOAD '$INPUT_PATH/FlumeData.*' USING com.twitter.elephantbird.pig.load.JsonLoader('-nestedLoad') AS myMap;

-- extract only id and text bexause we need to perform sentiment analysis on the actual text
extract_details = FOREACH load_tweets GENERATE myMap#'id' as id,myMap#'text' as text;

-- generate one tuple for each word in the text
tokens = foreach extract_details generate id,text, FLATTEN(TOKENIZE(text)) As word;

-- load the AFINN.txt which has a word, rating pair
dictionary = load '$INPUT_PATH/AFINN.txt' using PigStorage('\t') AS(word:chararray,rating:int);

-- do a replicated left outer join because word is a small relation compared to tweets relation
word_rating = join tokens by word left outer, dictionary by word using 'replicated';

-- project only id, rating and text because we need only these fields to perform sentiment analysis
rating = foreach word_rating generate tokens::id as id,tokens::text as text, dictionary::rating as rate;

-- group the tuples by id,text pair so that we can find the average rating for each tweet
word_group = group rating by (id,text);

-- find average rating for each tweet
avg_rate = foreach word_group generate group.id as tweet_id,group.text AS tweet_text, AVG(rating.rate) as tweet_rating;

-- positive tweets are those tweets which have a positive rating	
positive_tweets = filter avg_rate by tweet_rating>=0;

-- store the output to local/hadoop file system
-- $OUTPUT_PATH is a property externalized in task.properties
STORE positive_tweets INTO '$OUTPUT_PATH';


