require 'dp'
require 'cunn'
require 'cutorch'

-- Load the mnist data set
ds = dp.Mnist()

-- Extract training, validation and test sets
trainInputs = ds:get('train', 'inputs', 'bchw'):cuda()
trainTargets = ds:get('train', 'targets', 'b'):cuda()
validInputs = ds:get('valid', 'inputs', 'bchw'):cuda()
validTargets = ds:get('valid', 'targets', 'b'):cuda()
testInputs = ds:get('test', 'inputs', 'bchw'):cuda()
testTargets = ds:get('test', 'targets', 'b'):cuda()

-- Create a two-layer network
module = nn.Sequential()
module:add(nn.Convert('bchw', 'bf')) -- collapse 3D to 1D
module:add(nn.Linear(1*28*28, 20))
module:add(nn.Tanh())
module:add(nn.Linear(20, 10))
module:add(nn.LogSoftMax()) 
module:cuda()

-- Create a three-layer network
--module = nn.Sequential()
--module:add(nn.Convert('bchw', 'bf')) -- collapse 3D to 1D
--module:add(nn.Linear(1*28*28, 10))
--module:add(nn.Tanh())
--module:add(nn.Linear(10, 10))
--module:add(nn.Linear(10, 10))
--module:add(nn.LogSoftMax()) 
--module:cuda()

-- Create a four-layer network
--module = nn.Sequential()
--module:add(nn.Convert('bchw', 'bf')) -- collapse 3D to 1D
--module:add(nn.Linear(1*28*28, 10))
--module:add(nn.Tanh())
--module:add(nn.Linear(10, 5))
--module:add(nn.Linear(5, 5))
--module:add(nn.Linear(5, 10))
--module:add(nn.LogSoftMax()) 
--module:cuda()





-- Use the cross-entropy performance index
criterion = nn.ClassNLLCriterion():cuda()

require 'optim'
-- allocate a confusion matrix
cm = optim.ConfusionMatrix(10)
-- create a function to compute 
function classEval(module, inputs, targets)
   cm:zero()
   for idx=1,inputs:size(1) do
      local input, target = inputs[idx],targets[idx]
      local output = module:forward(input)
      cm:add(output, target)
   end
   cm:updateValids()
   return cm.totalValid
end

 require 'dpnn'
function trainEpoch(module, criterion, inputs, targets)
   for i=1,inputs:size(1) do
      local idx = math.random(1,inputs:size(1))
      local input, target = inputs[idx], targets[idx] 
      -- forward
      local output = module:forward(input)
      local loss = criterion:forward(output, target)
      -- backward
      local gradOutput = criterion:backward(output, target)
      module:zeroGradParameters()
      local gradInput = module:backward(input, gradOutput)
      -- update
      module:updateGradParameters(0.9) -- momentum (dpnn)
      module:updateParameters(0.1) -- W = W - 0.1*dL/dW
   end
end

 bestAccuracy, bestEpoch = 0, 0
wait = 0
for epoch=1,30 do
   trainEpoch(module, criterion, trainInputs, trainTargets)
   local validAccuracy = classEval(module, validInputs, validTargets)
   if validAccuracy > bestAccuracy then
      bestAccuracy, bestEpoch = validAccuracy, epoch
      --torch.save("/path/to/saved/model.t7", module)
      print(string.format("New maxima : %f @ %f", bestAccuracy, bestEpoch))
      wait = 0
   else
      wait = wait + 1
      if wait > 30 then break end
   end
end
testAccuracy = classEval(module, testInputs, testTargets)
print(string.format("Test Accuracy : %f ", testAccuracy))
