#  Copyright 2013 (c) Diego Souza <dsouza@c0d3.xxx>
#   
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#   
#      http://www.apache.org/licenses/LICENSE-2.0
#   
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

class LeelaException(Exception):
  def __init__(self, msg, code):
    super(LeelaException, self).__init__(msg)
    self.code = code

class UserException(LeelaException):
  def __init__(self, msg, code):
    super(UserException, self).__init__(msg, code)

class ServerException(LeelaException):
  def __init__(self, msg, code):
    super(ServerException, self).__init__(msg, code)

class BadRequestError(UserException):
  def __init__(self, msg, code):
    super(BadRequestError, self).__init__(msg, code)

class ForbiddenError(UserException):
  def __init__(self, msg, code):
    super(ForbiddenError, self).__init__(msg, code)

class NotFoundError(UserException):
  def __init__(self, msg, code):
    super(NotFoundError, self).__init__(msg, code)

class InternalServerError(ServerException):
  def __init__(self, msg, code):
    super(InternalServerError, self).__init__(msg, code)
