import json
with open('pokedex.json') as data_file:    
    data = json.load(data_file)

for s in data:
 data[s]['pokeball']+=5
 data[s]['masterball']+=1

obj = json.dumps(data)
f = open('pokedex.json','w')
f.write(obj)
f.close()
