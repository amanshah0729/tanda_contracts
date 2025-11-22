Setup functions
Both the unit and fuzz test examples shown above create an instance of the Counter contract. You can share setup logic like that across tests using the setUp function, which is called before each test execution:

contract CounterTest {
  Counter counter;

  function setUp() public {
    counter = new Counter();
  }

  function testInc() public {
    counter.inc();
    require(counter.count() == 1, "count should be 1");
  }

  function testIncBy(uint by) public {
    counter.incBy(by);
    require(counter.count() == by, "count should match the 'by' value");
  }
}

Running Solidity tests
You can run all the tests in your Hardhat project using the test task:

npm
pnpm
Yarn
Terminal window
npx hardhat test

If you only want to run your Solidity tests, use the test solidity task instead:

npm
pnpm
Yarn
Terminal window
npx hardhat test solidity

You can also pass one or more paths as arguments to these tasks, in which case only those files are executed:

npm
pnpm
Yarn
Terminal window
npx hardhat test <test-file-1> <test-file-2> ...

Configuring Solidity tests
You can configure how Solidity tests are executed in your Hardhat configuration.

Configuring the tests location
By default, Hardhat treats every Solidity file in the test/ directory as a test file. To use a different location, set the paths.tests.solidity field:

hardhat.config.ts
import { defineConfig } from "hardhat/config";

export default defineConfig({
  /// ... other config ...
  paths: {
    tests: {
      solidity: "./solidity-tests",
    },
  },
});

Configuring the tests execution
To configure how Solidity tests are executed, use the test.solidity object in the Hardhat configuration.

For example, the ffi cheatcode is disabled by default for security reasons, but you can enable it:

hardhat.config.ts
import { defineConfig } from "hardhat/config";

export default defineConfig({
  /// ... other config ...
  test: {
    solidity: {
      ffi: true,
    },
  },
});

It’s also possible to modify the execution environment of the tests. For example, you can modify the address that is returned by msg.sender:

hardhat.config.ts
import { defineConfig } from "hardhat/config";

export default defineConfig({
  /// ... other config ...
  test: {
    solidity: {
      sender: "0x1234567890123456789012345678901234567890",
    },
  },
});