# encoding: utf-8
require "sinatra"
require "json"
require "httparty"
require "date"
require "redis"
require "dotenv"
require "oauth"
require 'securerandom'
require 'rubygems'
require 'weather-api'
require 'open-uri'
require 'json'

configure do
  # Load .env vars
  Dotenv.load
  # Disable output buffering
  $stdout.sync = true
  # Exclude messages that match this regex
  set :ignore_regex, Regexp.new(ENV["IGNORE_REGEX"], "i")
  # Respond to messages that match this
  set :reply_regex, Regexp.new(ENV["REPLY_REGEX"], "i")
  # Mute if this message is received
  set :mute_regex, Regexp.new(ENV["MUTE_REGEX"], "i")
  # Unmute if this message is received
  set :unmute_regex, Regexp.new(ENV["UNMUTE_REGEX"], "i")

#  set :forme, Regexp.new(ENV["FORME"],"i")
  # Set up redis
  case settings.environment
  when :development
    uri = URI.parse(ENV["LOCAL_REDIS_URL"])
  when :production
    uri = URI.parse(ENV["REDISCLOUD_URL"])
  end
  $redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
end

$isQuizz = false
$forme = 0.1
$question = ''
$reponse = ''
$nombre = 0
$try = 0
$deck_id = nil
$isGame = false
$listPlay = Array.new

$word_list = ["Uranium","Arme","Pouvoir","Jockey","Tableau","beurre","potage","pomme", "poire", "train", "citron", "avocat","cuisine","chapeau", "oranges","langue","chut","voile","blondinnet","photographe","graphiste","processing","rouge","vernis","voiture","bouche","amitie","bijoux","joyeux","planant","evasif","hilarant","bonnet","rire","pantalon","echarpe","saleté","jeu","Donald","Marsupilami","Barbapapa","code","mort", "armoire", "boucle","buisson","bureau","chaise","carton","couteau","fichier","garage","glace","journal","kiwi","lampe","liste","montagne","remise","sandale","taxi","vampire","volant","MAISON","ÉBÉNISTE","CARTABLE","ÉTHIOPIE","ÉVÉNEMENT","ENRHUMÉ","ÉBOULEMENT","CYBERNÉTIQUE","DACTYLOGRAPHIE","CORPORATION","CELLOPHANE","BUANDERIE","BÉNÉDICTION","BELVÉDÈRE","ARBORICULTURE","ANGUILLE","OBSTACLE","ACCESSOIRE","ACADÉMIQUE","MOINEAU","MILITAIRE","MODESTEMENT","MISÉRICORDE","MERGUEZ","JADIS","JAUNISSEMENT","JAVELOT","IRRÉVOCABLE","IVRESSE","INVENTION","INCURSION","HARMONICA","HAMSTER","HABITATION","GUIRLANDE","GUIMAUVE","ROBINETTERIE","RIZIÈRE","ROCAILLE","SCÈNE","sALOPETTE","PROVERBE","PROSTERNATION","PROLONGEMENT","PROMISCUITÉ","PROCESSUS","RÉVOCABLE","RICHESSE","RICOCHET","RIVE","ROMBIÈRE","VAGUEMENT","VEINARD","VERNISSAGE","WHISKY","XYLOPHONE","YOGHOURT","ZÈLE","ZODIAC","ZIZANIE"]
$word = ""
$isPendu = false
$penduE = 7
$profil = {
  'U02QQPAD7' => 'Luc',
  'U036R6849' => 'Leo',
  'U02P1BK81' => 'Remi',
  'U055HN762' => 'Vince',
  'U02QSQC5R' => 'Quentin',
  'U056J5QAT' => 'Jules'
}

$lastFap = {
 'U02QQPAD7' => Time.new(2002),
  'U036R6849' => Time.new(2002),
  'U02P1BK81' => Time.new(2002),
  'U055HN762' => Time.new(2002),
  'U02QSQC5R' => Time.new(2002),
  'U056J5QAT' => Time.new(2002)
}

$scores = {
'Jules' => 0,
'Remi' => 0,
'Leo' => 0,
'Luc' => 0,
'Vince' => 0,
'Quentin' => 0
}




get "/" do
  "hi."
end


#get "/meme" do
#str =""
#response = open('http://memegen.link/templates/').read
#response = JSON.parse(response)
#puts response.class
#x = response.map { |key, value| value }
#for y in x
#str = str + '<h1>' + y.split('/')[-1] + '</h1>'
#str = str + '<img src="http://memegen.link/'+  y.split('/')[-1] +'/louka-casse-couille.jpg">'
#end
#body str
#end

get "/markov" do
  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"]
    count = params[:count].nil? ? 1 : [params[:count].to_i, 100].min
    body = []
    count.times do
      body << build_markov
    end
    status 200
    headers "Access-Control-Allow-Origin" => "*"
    body body.join("\n")
  else
    status 403
    body "Nope."
  end
end

get "/form" do
  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"]
    status 200
    erb :form
  else
    status 403
    body "Nope."
  end
end

post "/markov" do
  begin
    response = ""
puts "zboub"
    if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match(settings.mute_regex)
      time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to_i
      reply = shut_up(time,params[:user_id])
      response = json_response_for_slack(reply)
    end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match(settings.unmute_regex)
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to_i
      reply = unshut()
      response = json_response_for_slack(reply)
   end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(C|c)ombien de %")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
      reply = how_forme()
      response = json_response_for_slack(reply)
    end




  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       !params[:text].nil? &&
       params[:text].match("!( |)(G|g)if")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+$
      reply = gif(params[:text])
      response = json_response_for_slack(reply)
    end



  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       !params[:text].nil? &&
       params[:text].match("!meme")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+$
      reply = meme(params[:text])
      response = json_response_for_slack(reply)
    end

if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
      params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("((S|s)alut)|((b|B)onjour)|((H|h)ello)|((c|C)oucou)")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+$
      reply = hello()
      response = json_response_for_slack(reply)
    end


  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob fapfap")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+$
      reply = fap(params[:user_id])
      response = json_response_for_slack(reply)
    end


  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob choisis un nombre")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
      $nombre = SecureRandom.random_number(100)
      $isGame = true
      $try = 0
      reply = "C'est bon j'ai choisis un nombre entre 0 et 100 !"
      response = json_response_for_slack(reply)
    end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob pendu")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to
      $word = $word_list.sample.downcase
      $wordC = $word.chars.to_a 
      reply = startP($word)
      response = json_response_for_slack(reply)
    end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(L|l):") &&
       $isPendu == true
      reply = penduPlay(params[:text])
      response = json_response_for_slack(reply)
    end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(M|m)ot:") &&
       $isPendu == true
      reply = propos(params[:text])
      response = json_response_for_slack(reply)
    end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(N|n)b:") &&
       $isGame == true
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
      reply = game(params[:text])
      response = json_response_for_slack(reply)
    end
  
  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob va prendre un caf(é|e)")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
      shut_up(5)
      reply = "Ok je reviens dans 5 minutes :coffee: "

      response = json_response_for_slack(reply)
    end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob m(é|e)t(é|e)o")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\$
      reply = meteo(params[:user_id])
      response = json_response_for_slack(reply)
    end


  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob tu parles trop")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
       reply = tg()
       response = json_response_for_slack(reply)
    end



  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("man (R|r)ob")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\$
       reply = man()
       response = json_response_for_slack(reply)
    end


  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob ((p|P)ierre|(p|P)apier|(C|c)iseau(x|))")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\$
       reply = ppc(params[:text])
       response = json_response_for_slack(reply)
    end


  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(C|c)alc:")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
       reply = calc(params[:text])
       response = json_response_for_slack(reply)
    end

  if $isQuizz == true
  s = $reponse.delete(' ').downcase()
  s.delete!("\n")
  s.gsub!(/[éèêë]/,'e')
s.gsub!(/[âàä]/,'a')
 s.gsub!(/[^0-9A-Za-z]/, '')
  puts "la reponse attendu est " + s
  text = params[:text].delete(' ').downcase()
  text.delete!("\n")
  text.gsub!(/[éèêë]/,'e')
  text.gsub!(/[âàä]/,'a')
  text.gsub!(/[^0-9A-Za-z]/, '')
  puts "Et tu as dis : " + text
  puts text==s
  end

  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       $isQuizz == true
       if text.match(s)
       puts "JE SUIS ICI"
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
     usert = params[:user_id]
    # puts "user = " + usert
      # winner = profil[':'+usert]
       winner =  $profil[usert]
       $scores[winner]+=1
       reply = "Bien ouej " + winner + " (" + $scores[winner].to_s + " pts)\nLa réponse était " + $reponse + "\n"
       ifWinText = ifWin(winner)
       reply = reply + ifWinText.to_s
       response = json_response_for_slack(reply)
       $reponse = ""
       $isQuizz = false
       end
    end



 if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(P|p)ose une question")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
       $isQuizz = true
       reply = quizz()
       response = json_response_for_slack(reply)
    end


 if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob score")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
       reply = classement()
       response = json_response_for_slack(reply)
    end

 if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob reset score")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
       resetScore()
       reply = "Les scores ont été remis à 0"
       response = json_response_for_slack(reply)
    end

if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(C|c)'était quoi la réponse") &&
       $isQuizz == true
       reply = "La réponse attendue était" + $reponse
       response = json_response_for_slack(reply)
       $reponse = ""
       $isQuizz = false
    end


  if params[:token] == ENV["OUTGOING_WEBHOOK_TOKEN"] &&
       params[:user_id] != "USLACKBOT" &&
       !params[:text].nil? &&
       params[:text].match("(R|r)ob parle plus")
      #time = params[:text].scan(/\d+/).first.nil? ? 60 : params[:text].scan(/\d+/).first.to$
       reply = parlepd()
       response = json_response_for_slack(reply)
    end


    # Ignore if text is a cfbot command, or a bot response, or the outgoing integration token doesn't match
    unless params[:text].nil? ||
           params[:text].match(settings.ignore_regex) ||
           params[:user_name].match(settings.ignore_regex) ||
           params[:user_id] == "USLACKBOT" ||
           params[:user_id] == "" ||
           params[:token] != ENV["OUTGOING_WEBHOOK_TOKEN"] ||
           $isQuizz == true


      # Store the text if someone is not manually invoking a reply
      # and if the selected user is defined and matches
      if !ENV["SLACK_USER"].nil?
        if !params[:text].match(settings.reply_regex) && (ENV["SLACK_USER"] == params[:user_name] || ENV["SLACK_USER"] == params[:user_id])
          $redis.pipelined do
            store_markov(params[:text])
          end
        end
      else
        if !params[:text].match(settings.reply_regex)
          $redis.pipelined do
            store_markov(params[:text])
          end
        end
      end






      # Reply if the bot isn't shushed AND either the random number is under the threshold OR the bot was invoked
      if (!$redis.exists("snarkov:shush") &&
         params[:user_id] != "WEBFORM" &&
         response == "" &&
        (rand <= $forme || params[:text].match(settings.reply_regex)))
                reply = build_markov
                response = json_response_for_slack(reply)
      end
    end
  rescue => error
    puts "[ERROR] #{error}"
    response = ""
  end

  status 200
  body response

end

def store_markov(text)
  # Split long text into sentences
  sentences = text.split(/\.\s+|\n+/)
  sentences.each do |t|
    # Horrible regex, this
    text = t.gsub(/<@([\w]+)>:?/){ |m| get_slack_name($1) }
            .gsub(/<#([\w]+)>/){ |m| get_channel_name($1) }
            .gsub(/<.*?>:?/, "")
            .gsub(/:-?\(/, ":disappointed:")
            .gsub(/:-?\)/, ":smiley:")
            .gsub(/;-?\)/, ":wink:")
            .gsub(/[‘’]/,"\'")
            .gsub(/\s_|_\s|_[,\.\?!]|^_|_$/, " ")
            .gsub(/\s\(|\)\s|\)[,\.\?!]|^\(|\)$/, " ")
            .gsub(/&lt;.*?&gt;|&lt;|&gt;|[\*`<>"“”•~]/, "")
            .downcase
            .strip
    # Split words into array
    words = text.split(/\s+/)
    # Ignore if phrase is less than 3 words
    unless words.size < 3
      puts "[LOG] Storing: #{text}"
      (words.size - 2).times do |i|
        # Join the first two words as the key
        key = words[i..i+1].join(" ")
        # And the third as a value
        value = words[i+2]
        # If it's the first pair of words, store in special set
        $redis.sadd("snarkov:initial_words", key) if i == 0
        $redis.sadd(key, value)
      end
    end
  end
end

def build_markov
  phrase = []
  # Get a random pair of words from Redis
  initial_words = $redis.srandmember("snarkov:initial_words")

  unless initial_words.nil?
    # Split the key into the two words and add them to the phrase array
    initial_words = initial_words.split(" ")
    first_word = initial_words.first
    second_word = initial_words.last
    phrase << first_word
    phrase << second_word

    # With these two words as a key, get a third word from Redis
    # until there are no more words
    while phrase.size <= ENV["MAX_WORDS"].to_i && new_word = get_next_word(first_word, second_word)
      # Add the new word to the array
      phrase << new_word
      # Set the second word and the new word as keys for the next iteration
      first_word, second_word = second_word, new_word
    end
  end
  phrase.join(" ").strip
end

def get_next_word(first_word, second_word)
  $redis.srandmember("#{first_word} #{second_word}")
end

def calc(text)
x = text.partition(':').last
is =  (x[/[^a-zA-Z]+/] == x)
if is
eval(x)
else
"T'as cru quoi fdp?"
end
end

def hello()
hello = ["Hello","Salut mofo","Salut bg","Coucou :heart:","Hi babe","Salut salut les voisinous","Aurevoir"]
return hello.sample
end

def startP(word)
$blank =""
$listPlay = Array.new
$penduE = 7
str = "Ok c'est parti :\n"
(0..(word.length-1)).each do
$blank += "-"
end
$isPendu = true
return str + $blank
end

def penduPlay(text)
puts $wordC
letter = (text.partition(':').last)
letter = letter.downcase
if letter.length ==1
 $listPlay.push(letter)
 if $wordC.index(letter) != nil
 #p =  $wordC.index(letter)
 #$blank[p]=letter
 p = $wordC.each_index.select{|i| $wordC[i] == letter}
 for po in p
 $blank[po]=letter
 end 
 if $blank == $word
 $isPendu = false
 $listPlay = Array.new
 $penduE = 7
 return "Bien ouej magueule!"
 else
 return $blank + "\n lettre jouée : " + $listPlay.to_s
 end
 else
 $penduE -=1
 return draw($penduE)
 end
else
"Une lettre à la fois fdp"
end
end

def propos(text)
letter = (text.partition(':').last)
if letter.downcase == $word.downcase
$listPlay = Array.new
$isPendu = false
$penduE = 7
"Bien ouej magueule!"
else
$penduE -=1
return draw($penduE)
end


end

def draw(t)
output = ""
 ascii = <<-eos
    _____
    |    #{t<7 ? '|':' '}
    |    #{t<6 ? 'O':' '}
    |   #{t<2 ? '/':' '}#{t<5 ? '|':' '}#{t<1 ? '\\':' '}
    |   #{t<4 ? '/':' '} #{t<3 ? '\\':' '}
    |
    ===
    eos
output << ascii
if t< 1
$listPlay = Array.new
$isPendu = false
$penduE = 7
return output + "\n*Loose* :poop:\n Le mot était " + $word
else
return output + "\n" + $blank + "\n lettre jouée : " + $listPlay.to_s
end
end

def fap(user) 
now = Time.now
puts now.hour
if (now.hour >= 7 && now.hour <= 16)
"Pas de fap en pleine journée"
else
diff = ((now-$lastFap[user])).to_i
if diff>600
 $lastFap[user]=Time.now
  if user == 'U0E760J3G'
  x = SecureRandom.random_number(1000)
  name = open('http://api.porn.com/actors/find.json?order=rating&limit=1&sex=trans&page=' + x.to_s).read
  name = JSON.parse(name)
  elsif user == 'U0BQC7PMJ'
  x = SecureRandom.random_number(1000)
  name = open('http://api.porn.com/actors/find.json?limit=1&order=rating&sex=male&page=' + x.to_s).read
  name = JSON.parse(name)
  else
  x = SecureRandom.random_number(2000)
  name = open('http://api.porn.com/actors/find.json?order=rating&limit=1&page=' + x.to_s).read
  name = JSON.parse(name)
  end
"Ok mofos, tu dois te fapper sur : " + "*" + name["result"][0]["name"] + "*\n\n" + name["result"][0]["thumb"]
else
"T'as déjà fini de te fapper sur la dernière sale précosse?"
end
end
end



def meme(text)
url = "http://memegen.link/templates/"
t = text.partition('!meme').last
if t.strip == "templates"
"10 Guy `tenguy`\n"\
"Afraid to Ask Andy `afraid`\n"\
"An Older Code Sir, But It Checks Out `older`\n"\
"Ancient Aliens Guy `aag`\n"\
"At Least You Tried `tried`\n"\
"Baby Insanity Wolf `biw`\n"\
"Bad Luck Brian `blb`\n"\
"But That's None of My Business `kermit`\n"\
"Butthurt Dweller `bd`\n"\
"Captain Hindsight `ch`\n"\
"Comic Book Guy `cbg`\n"\
"Condescending Wonka `wonka`\n"\
"Confession Bear `cb`\n"\
"Conspiracy Keanu `keanu`\n"\
"Dating Site Murderer `dsm`\n"\
"Do It Live! `live`\n"\
"Do You Want Ants? `ants`\n"\
"Doge `doge`\n"\
"Drake Always On Beat `alwaysonbeat`\n"\
"Ermahgerd `ermg`\n"\
"First World Problems `fwp`\n"\
"Forever Alone `fa`\n"\
"Foul Bachelor Frog `fbf`\n"\
"Fuck Me, Right? `fmr`\n"\
"Futurama Fry `fry`\n"\
"Good Guy Greg `ggg`\n"\
"Hipster Barista `hipster`\n"\
"I Can Has Cheezburger? `icanhas`\n"\
"I Feel Like I'm Taking Crazy Pills `crazypills`\n"\
"I Immediately Regret This Decision! `regret`\n"\
"I Should Buy a Boat Cat `boat`\n"\
"I Would Be So Happy `sohappy`\n"\
"I am the Captain Now `captain`\n"\
"Inigo Montoya `inigo`\n"\
"Insanity Wolf `iw`\n"\
"It's A Trap! `ackbar`\n"\
"It's Happening `happening`\n"\
"It's Simple, Kill the Batman `joker`\n"\
"Jony Ive Redesigns Things `ive`\n"\
"Laughing Lizard `ll`\n"\
"Matrix Morpheus `morpheus`\n"\
"Milk Was a Bad Choice `badchoice`\n"\
"Minor Mistake Marvin `mmm`\n"\
"Nothing To Do Here `jetpack`\n"\
"Oh, Is That What We're Going to Do Today? `red`\n"\
"One Does Not Simply Walk into Mordor `mordor`\n"\
"Oprah You Get a Car `oprah`\n"\
"Overlay Attached Girlfriend `oag`\n"\
"Pepperidge Farm Remembers `remembers`\n"\
"Philosoraptor `philosoraptor`\n"\
"Probably Not a Good Idea `jw`\n"\
"Sad Barack Obama `sad-obama`\n"\
"Sad Bill Clinton `sad-clinton`\n"\
"Sad Frog / Feels Bad Man `sadfrog`\n"\
"Sad George Bush `sad-bush`\n"\
"Sad Joe Biden `sad-biden`\n"\
"Sad John Boehner `sad-boehner`\n"\
"Sarcastic Bear `sarcasticbear`\n"\
"Schrute Facts `dwight`\n"\
"Scumbag Brain `sb`\n"\
"Scumbag Steve `ss`\n"\
"Sealed Fate `sf`\n"\
"See? Nobody Cares `dodgson`\n"\
"Shut Up and Take My Money! `money`\n"\
"So Hot Right Now `sohot`\n"\
"Socially Awesome Awkward Penguin `awesome-awkward`\n"\
"Socially Awesome Penguin `awesome`\n"\
"Socially Awkward Awesome Penguin `awkward-awesome`\n"\
"Socially Awkward Penguin `awkward`\n"\
"Stop Trying to Make Fetch Happen `fetch`\n"\
"Success Kid `success`\n"\
"Super Cool Ski `Instructor ski`\n"\
"That Would Be Great `officespace`\n"\
"The Most Interesting Man in the World `interesting`\n"\
"The Rent Is Too Damn High `toohigh`\n"\
"This is Bull, Shark `bs`\n"\
"Why Not Both? `both`\n"\
"Winter is coming `winter`\n"\
"X all the Y `xy`\n"\
"X, X Everywhere `buzz`\n"\
"Xzibit Yo Dawg `yodawg`\n"\
"Y U NO Guy `yuno`\n"\
"Y'all Got Any More of Them `yallgot`\n"\
"You Should Feel Bad `bad`\n"\
"You Sit on a Throne of Lies `elf`\n"\
"You Were the Chosen One! `chosen`"
else
template = (t.partition(':').first).strip
text = (t.partition(':').last).strip
puts "template :" + template
puts "text : " + text
text.gsub!(' ','_') 
text.gsub!(/[éèêë]/,'e')
text.gsub!(/[àâä]/,'a')
url + template + '/' + text + '.jpg'
end
end

def ppc(text)
ppc = (text.partition('Rob').last)
r = SecureRandom.random_number(3)
if ppc.match("(p|P)ierre")
u = 1
elsif ppc.match("(P|p)apier")
u = 2
else
u = 3
end

if r==1
rt = "Pierre"
elsif r==2
rt = "Papier"
else
rt = "Ciseaux"
end

if r==1 && u==1
w = 0
elsif r==1 && u==2
w = 1
elsif r==1 && u==3
w = 2
elsif r==2 && u==1
w = 2
elsif r==2 && u==2
w =0
elsif r==2 && u==3
w = 1
elsif r==3 && u==1
w = 1
elsif r==3 && u==2
w = 2
else
w = 0
end

if w==0
st = "Match nul"
elsif w==1
st = "Bien ouej mofo"
else
st = "Sorry mofo" 
end

"Tu as dis" + ppc + " et j'ai dis " + rt + "\n" + st
end



def game(text)
nbP = (text.partition(':').last).to_i
$try +=1
puts "nombre a trouver : " + $nombre.to_s

if nbP != $nombre
if $try >= 5
 lenb = $nombre
  $try = 0
  $nombre = 0
  $isGame = false
  return "Sale noob, c'était " + lenb.to_s + " :shit:"

end
end

if nbP < $nombre
  puts " trop petit"
  return  "Essai " + $try.to_s + ": C'est trop petit"
elsif nbP > $nombre
  puts "trop grand"
  return  "Essai " + $try.to_s + ": C'est trop grand"
else
  puts "win"
  nbtry = $try
  $try = 0
  $nombre = 0
  $isGame = false
  return "Bien ouej, en " + nbtry.to_s + " coups! :trophy: "
end

end

def shut_up(minutes = 60,id = 'U0B1S7SGG')
  if id == "U0E760J3G"
   "Toi ta gueule!"
  else
   minutes = [minutes, 60*24].min
   if minutes > 0
     $redis.setex("snarkov:shush", minutes * 60, "true")
     puts "[LOG] Shutting up: #{minutes} minutes"
     if minutes == 1
      "ok ff .. je la ferme pendant #{minutes} minute"
     else
      "ok ff .. je la ferme pendant #{minutes} minutes"
     end
   end
 end
end

def unshut()
 $redis.del("snarkov:shush")
 puts "[LOG] Ok merci thug"
 "merci bg"
end

def gif(text)
t = text.partition('!gif').last
puts "tu cherche un gif de " + t
response = open('http://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag='+t).read
response = JSON.parse(response)
if response["data"].empty? != true
puts "il existe"
response["data"]["fixed_width_downsampled_url"]
else
puts "jtrouve pas"
boob = open('http://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=boobs').read
boob = JSON.parse(boob)
"Je trouve rien correspondant à ta recherche, voilà des boobs :\n" + boob["data"]["fixed_width_downsampled_url"]
end
end


def ifWin(user)
 if $scores[user]>=5
 resetScore()
 user + " le boss gagne! :trophy:"
 else
 " "
 end
end

def resetScore()
$scores = {
'Jules' => 0,
'Leo' => 0,
'Luc' => 0,
'Remi' => 0
}
end

def tg()
 if $forme >= 0.1
  $forme = ($forme - 0.1).round(2)
  "Ok mofos, je vais moins parler :cry: "
 else
  "Je suis déjà au minimum :sob: "
 end
end

def parlepd()
 if $forme >= 0.9
  $forme = 1.0
  "Je suis déjà à 100% :sunglasses: "
 else
  $forme = ($forme + 0.1).round(2)
  "Ok ma gueule! :heart: "
  end
end

def meteo(user)
if user == "U0B1QHR7G"
wea = Weather.lookup(576155, Weather::Units::CELSIUS)
weatherT =wea.title + "\n" + wea.condition.temp.to_s + " degrés, " + wea.condition.text
weatherT = weatherT + "\n\n *Prévision* : \n"
weatherT = weatherT +  wea.forecasts[0].day + " :point_right: " + wea.forecasts[0].text + ", " + wea.forecasts[0].low.to_s + "/" + wea.forecasts[0].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[1].day + " :point_right: " + wea.forecasts[1].text + ", " + wea.forecasts[1].low.to_s + "/" + wea.forecasts[1].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[2].day + " :point_right: " + wea.forecasts[2].text + ", " + wea.forecasts[2].low.to_s + "/" + wea.forecasts[2].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[3].day + " :point_right: " + wea.forecasts[3].text + ", " + wea.forecasts[3].low.to_s + "/" + wea.forecasts[3].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[4].day + " :point_right: " + wea.forecasts[4].text + ", " + wea.forecasts[4].low.to_s + "/" + wea.forecasts[4].high.to_s + " degrés\n"
weatherT

else
wea = Weather.lookup(580778, Weather::Units::CELSIUS)
weatherT =wea.title + "\n" + wea.condition.temp.to_s + " degrés, " + wea.condition.text
weatherT = weatherT + "\n\n *Prévision* : \n"
weatherT = weatherT +  wea.forecasts[0].day + " :point_right: " + wea.forecasts[0].text + ", " + wea.forecasts[0].low.to_s + "/" + wea.forecasts[0].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[1].day + " :point_right: " + wea.forecasts[1].text + ", " + wea.forecasts[1].low.to_s + "/" + wea.forecasts[1].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[2].day + " :point_right: " + wea.forecasts[2].text + ", " + wea.forecasts[2].low.to_s + "/" + wea.forecasts[2].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[3].day + " :point_right: " + wea.forecasts[3].text + ", " + wea.forecasts[3].low.to_s + "/" + wea.forecasts[3].high.to_s + " degrés\n"
weatherT = weatherT +  wea.forecasts[4].day + " :point_right: " + wea.forecasts[4].text + ", " + wea.forecasts[4].low.to_s + "/" + wea.forecasts[4].high.to_s + " degrés\n"
weatherT
end
end

def quizz()
filename = 'questions'
line_count = `wc -l "#{filename}"`.strip.split(' ')[0].to_i
x = SecureRandom.random_number(line_count-1)
target = open('rand', 'a')
ra = x.to_s + "\n"
target.write(ra)
puts "rand : " + x.to_s
line = IO.readlines(filename)[x]
tab = line.partition("->")
puts "question : " +  tab[0]
puts "reponse : " + tab[2]
$reponse = tab[2]
$question = tab[0]
$question
end

def classement()
$scores.to_s
end

def man()
"*MAN DE ROB* \n\n" \
"Par défaut Rob répond à 10% des messages \n"\
":point_right: Pour augmenter son % chance de réponses :\n"\
"_Rob parle plus_\n"\
":point_right: Pour diminuer son % de chance de réponses :\n"\
"_Rob tu parles trop_\n"\
":point_right: Pour connaitre son % de chance de réponses :\n"\
"_Rob combien de % ?_\n"\
":point_right: Pour mute Rob pendant une certain temps :\n"\
"_Rob ta gueule [nb de minutes]_ (par défaut 60)\n"\
"_Rob va prendre un café_ (Mute pendant 5 minutes)\n"\
":point_right: Pour faire revenir Rob lorsqu'il est mute :\n"\
"_Rob tu me manques_\n\n"\
" *CALCULATRICE* \n"\
":point_right: Pour faire résoudre à Rob un calcul :\n"\
"_calc: [calcul]_\n\n"\
" *METEO :mostly_sunny:*\n"\
":point_right: Pour connaitre la météo et les prévisions :\n"\
"_Rob météo_\n\n"\
" *GUESSING GAME (5 essais)*\n"\
":point_right: Pour lancer une partie :\n"\
"_Rob choisis un nombre_\n"\
":point_right: Pour proposer une nombre :\n"\
"_nb:[nombre]_\n\n"\
" *QUIZZ* \n"\
"Les quizz se joue en 5 points\n"\
":point_right: Pour demander à Rob de poser une question :\n"\
"_[Rob] Pose une question_\n"\
":point_right: Pour lui demandait la réponse :\n"\
"_[Rob] C'était quoi la réponse?_\n"\
":point_right: Pour connaitre le score de tous le monde :\n"\
"_Rob score_\n"\
":point_right: Pour réinitialiser le score :\n"\
"_Rob reset score_\n"\
"*Lorsqu'une question de quizz est en cours, Rob est mute et ne stock plus nos pépites en base. Penser donc à arrêter le quizz en donnant la bonne réponse ou en lui demande la réponse*\n\n"\
" *GIF* \n"\
":point_right: Pour demander à Rob un gif de ouf :\n"\
"_!Gif [whatyouwant]_\n"\
"* Si Rob ne trouve pas de gif correspondant à votre recherche, vous aurez un gif de boobs parceque c'est toujours sympa*\n\n"\
" *FAP TIME :sweat_drops:* \n"\
":point_right: En manque d'inspiration pour le fap time ? :\n"\
"_Rob fapfap_\n\n"\
" *MEME GENERATOR* \n"\
":point_right: Pour générer son propre meme :\n"\
"_`!*meme [template]: [text]`_\n"\
":point_right: Pour avoir la liste des templates disponibles :\n"\
"_`!*meme templates`_\n"\
"_Pour le texte utiliser '/' pour le retour à la ligne_\n\n"\
" *Jeu du pendu*\n"\
":point_right: Pour lancer une partie :\n"\
"_Rob pendu_\n"\
":point_right: Pour proposer une lettre :\n"\
"_l:[lettre]_\n"\
":point_right: Pour proposer un mot :\n"\
"_mot:[mot]_"

end


def how_forme()
 puts "[LOG] ma forme blabla"
 if $forme >= 0.5

 ($forme*100).to_s + " :sunglasses:"
 else
 ($forme*100).to_s + " :cry:"
 end
end

def json_response_for_slack(reply)
  puts "[LOG] Replying: #{reply}"
  response = { text: reply, link_names: 1 }
  response[:username] = ENV["BOT_USERNAME"] unless ENV["BOT_USERNAME"].nil?
  response[:icon_emoji] = ENV["BOT_ICON"] unless ENV["BOT_ICON"].nil?
  response.to_json
end

def get_slack_name(slack_id)
  username = ""
  uri = "https://slack.com/api/users.list?token=#{ENV["API_TOKEN"]}"
  request = HTTParty.get(uri)
  response = JSON.parse(request.body)
  if response["ok"]
    user = response["members"].find { |u| u["id"] == slack_id }
    unless user.nil?
      if !user["profile"].nil? && !user["profile"]["first_name"].nil?
        username = user["profile"]["first_name"]
      else
        username = user["name"]
      end
    end

  else
    puts "Error fetching user: #{response["error"]}" unless response["error"].nil?
  end
  username
end

def get_slack_user_id(username)
  user_id = nil
  uri = "https://slack.com/api/users.list?token=#{ENV["API_TOKEN"]}"
  request = HTTParty.get(uri)
  response = JSON.parse(request.body)
  if response["ok"]
    user = response["members"].find { |u| u["name"] == username.downcase }
    user_id = "#{user["id"]}" unless user.nil?
  else
    puts "Error fetching user ID: #{response["error"]}" unless response["error"].nil?
  end
  user_id
end

def get_channel_id(channel_name)
  uri = "https://slack.com/api/channels.list?token=#{ENV["API_TOKEN"]}"
  request = HTTParty.get(uri)
  response = JSON.parse(request.body)
  if response["ok"]
    channel = response["channels"].find { |u| u["name"] == channel_name.gsub("#","") }
    channel_id = channel["id"] unless channel.nil?
  else
    puts "Error fetching channel id: #{response["error"]}" unless response["error"].nil?
    channel_id = ""
  end
  channel_id
end

def get_channel_name(channel_id)
  channel_name = ""
  uri = "https://slack.com/api/channels.list?token=#{ENV["API_TOKEN"]}"
  request = HTTParty.get(uri)
  response = JSON.parse(request.body)
  if response["ok"]
    channel = response["channels"].find { |u| u["id"] == channel_id }
    channel_name = "##{channel["name"]}" unless channel.nil?
  else
    puts "Error fetching channel name: #{response["error"]}" unless response["error"].nil?
  end
  channel_name
end



