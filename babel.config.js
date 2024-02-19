module.exports = {
    // "plugins": ["@babel/plugin-proposal-decorators", { "version": "2023-05" }]
    "plugins": [
        ["@babel/plugin-proposal-decorators", { "legacy": true}],
        ["@babel/plugin-proposal-class-properties", { "loose": true}]
    ]
};