const { parse } = require('@babel/parser');

module.exports = function(fileInfo, api) {
  const j = api.jscodeshift;
  const root = j(fileInfo.source);

  // Find and remove all console.log statements
  root.find(j.CallExpression, {
    callee: {
      object: { name: 'console' },
      property: { name: 'log' }
    }
  }).forEach(path => {
    // Remove the entire statement
    j(path).closest(j.ExpressionStatement).remove();
  });

  return root.toSource();
};

module.exports.parser = {
  parse: (source) => {
    return parse(source, {
      sourceType: 'module',
      plugins: ['typescript', 'jsx']
    });
  }
};
