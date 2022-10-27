
const { SolidityMetricsContainer } = require('solidity-code-metrics');
const { exportAsHtml } = require('solidity-code-metrics/src/metrics/helper.js');

let options = {
  basePath: "",
  inputFileGlobExclusions: undefined,
  inputFileGlob: undefined,
  inputFileGlobLimit: undefined,
  debug: false,
  repoInfo: {
    branch: undefined,
    commit: undefined,
    remote: undefined
  }
}

let metrics = new SolidityMetricsContainer("Float Arctic Contracts", options);


// analyze files
metrics.analyze("./contracts/oracles/OracleManager.sol");
metrics.analyze("./contracts/YieldManagers/MarketLiquidityManagerSimple.sol");
metrics.analyze("./contracts/market/template/MarketExtended.sol");
metrics.analyze("./contracts/market/template/MarketCore.sol");
metrics.analyze("./contracts/PoolToken/PoolToken.sol");


var fs = require('fs');
var path = require('path');
const appRoot = path.resolve(__dirname);
const outputDirectory = path.resolve(appRoot, "../code-metrics");
const outputDirectoryHtml = path.resolve(outputDirectory, "html");


// console.log(metrics.totals());
const getResults = async () => {
  let dotGraphs = {};
  try {
    dotGraphs = metrics.getDotGraphs();
  } catch (error) {
    console.log(error);
  }

  const text = await metrics.generateReportMarkdown();
  if (!fs.existsSync(outputDirectory)) {
    fs.mkdirSync(outputDirectory, { recursive: true });
  }
  fs.writeFileSync(path.resolve(outputDirectory, "metrics.md"), text);

  if (!fs.existsSync(outputDirectoryHtml)) {
    fs.mkdirSync(outputDirectoryHtml, { recursive: true });
  }
  const htmlOutput = exportAsHtml(text, metrics.totals(), dotGraphs);
  fs.writeFileSync(path.resolve(outputDirectoryHtml, "metrics.html"), htmlOutput);
}

getResults();
