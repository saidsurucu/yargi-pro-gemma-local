# Yargi Pro remote MCP'yi global opencode config'e ekler (resmi snippet).
# Auth: ilk kullanimda opencode OAuth akisini yurutur (manuel token yok).
$node = @'
const fs=require("fs"),os=require("os"),path=require("path");
const dir=path.join(os.homedir(),".config","opencode"),file=path.join(dir,"opencode.json");
fs.mkdirSync(dir,{recursive:true});
let cfg={};try{cfg=JSON.parse(fs.readFileSync(file,"utf8"))}catch{}
if(typeof cfg!=="object"||cfg===null||Array.isArray(cfg))cfg={};
if(!cfg["$schema"])cfg["$schema"]="https://opencode.ai/config.json";
if(typeof cfg.mcp!=="object"||cfg.mcp===null)cfg.mcp={};
cfg.mcp["yargi-mcp-pro"]={type:"remote",url:"https://yargi.betaspacestudio.com/mcp"};
fs.writeFileSync(file,JSON.stringify(cfg,null,2)+"\n");
console.log("yargi-mcp-pro eklendi -> "+file);
'@
$node | node -
