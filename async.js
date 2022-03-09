//demos how to wait for an event in a async fashion
function custEvent(event) {
  console.log("cust event:"+event.detail);
}
var event = new CustomEvent("special", {detail: "The detail"});
// Listen for the event.
//document.addEventListener('special', custEvent, false);
// Dispatch the event.
//document.dispatchEvent(event);

function waitListener(el) {
    return new Promise(function (resolve, reject) {
        var evfunc = function(event) {
            el.removeEventListener("special", evfunc);
            resolve(event);
        };
        el.addEventListener("special", evfunc,false);
    });
}

setTimeout(function() {
  document.dispatchEvent(event);
},2000);

async function awaitEv(){
  console.log("before");
  await waitListener(document).then(function(e){
    console.log("e.detail: "+e.detail);
  });
  console.log("after");
}

awaitEv();

