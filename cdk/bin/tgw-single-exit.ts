#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { TgwSingleExitStack } from '../lib/tgw-single-exit-stack';

const app = new cdk.App();
new TgwSingleExitStack(app, 'TgwSingleExitStack', {

  /* Uncomment the next line if you know exactly what Account and Region you
   * want to deploy the stack to. */
  env: { region: 'us-east-2' },

});