--[[
  Data loader for text experiments

  The five entries of the each batch are:
  [1] source   : source sentence
  [2] source_l : max source length within the batch
  [3] target   : target sentence (shifted source sentence in this autoencoding task)
  [4] target_l : max source length within the batch
  [5] batch_l  : batch size
--]]

require 'hdf5'

local data = torch.class("data")

--[[ constructor ]]--
function data:__init(opt, data_file)
   local f = hdf5.open(data_file, 'r')
   self.source = f:read('source'):all()
   self.batch_l = f:read('batch_l'):all()
   self.source_l = f:read('source_l'):all()  -- max source length each batch
   self.batch_idx = f:read('batch_idx'):all()
   self.vocab_size = f:read('vocab_size'):all()[1]
   self.length = self.batch_l:size(1)
   self.seq_length = self.source:size(2)
   self.batches = {}
   for i = 1, self.length do
     local source_i = self.source:sub(self.batch_idx[i], self.batch_idx[i]+self.batch_l[i]-1,
    			     1, self.source_l[i]):transpose(1,2)
     local target_i = source_i[{{2, self.source_l[i]}, {}}]
     table.insert(self.batches, {source_i, self.source_l[i], target_i, self.source_l[i]-1,
    			self.batch_l[i]})
   end
   -- pre-allocated buffers
   self.source_ = opt.gpuid>=0 and torch.CudaTensor() or torch.Tensor()
   self.source_l_ = 0
   self.target_ = opt.gpuid>=0 and torch.CudaTensor() or torch.Tensor()
   self.target_l_ = 0
   self.batch_l_ = 0
end

--[[ size function ]]--
function data:size()
   return self.length
end

--[[ __index special method ]]--
function data.__index(self, idx)
   if type(idx) == "string" then
      return data[idx]
   else
      local source = self.batches[idx][1]
      local source_l = self.batches[idx][2]
      local target = self.batches[idx][3]
      local target_l = self.batches[idx][4]
      local batch_l = self.batches[idx][5]
      -- fill up buffers
      self.source_:resize(unpack(source:size():totable())):copy(source)
      self.source_l_ = source_l
      self.target_:resize(unpack(target:size():totable())):copy(target)
      self.target_l_ = target_l
      self.batch_l_ = batch_l
      return {self.source_, self.source_l_, self.target_, self.target_l_, self.batch_l_}
   end
end

return data
