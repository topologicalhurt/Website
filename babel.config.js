module.exports = {
    plugins: [
        // ["@babel/plugin-proposal-decorators", {"version": "2023-05"}],
        ["@babel/plugin-proposal-decorators", {"version": "2023-05", 
        "decoratorsBeforeExport": false}],
        "@babel/plugin-transform-class-static-block",
        ["@babel/plugin-proposal-class-properties", { "loose": true }]
    ]
};