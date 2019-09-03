var Objects_To_Arrays = function(objs, keys) {
  var headers = []
  var props = []
  var data = [
    headers
  ]
  // define headers and properties check
  if (!keys) {
    var keys = objs.sort(function(a,b) { // order by most properties
      var counter = function(obj) {
        var count = 0
        for (var o in obj) {
          count = count + 1
        }
        return count
      }
      var a1 = counter(a)
      var b1 = counter(b)
      return b1 - a1
    })[0];
      for (var key in keys) { // get property names
        headers.push(key.replace(/_/g, ' ').toUpperCase());
        props.push(key);
      };
  }
  else {
    props = keys;
    for (var i = 0; i < keys.length; i++) {
      headers.push(keys[i].replace(/_/g, ' ').toUpperCase());
    };
  };
  //define content
  for (var i = 0; i < objs.length; i++) {
    var row = []
    var obj = objs[i]
    for (var j = 0; j < props.length; j++) {
      var prop = props[j]
      row.push(obj.hasOwnProperty(prop) ? String(obj[prop]) : '-');
    }
    data.push(row)
  }
  return data;
};
